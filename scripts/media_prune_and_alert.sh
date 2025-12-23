#!/usr/bin/env bash
set -euo pipefail

# =========================
# CONFIG
# =========================
MOUNT="/mnt/media"

WARN_PCT=85
CRIT_PCT=90

# -------------------------
# Sonarr
# -------------------------
SONARR_URL="http://192.168.5.81:8989"
SONARR_API_KEY="REPLACE_ME"

# Keep seasons NEWER than this many days (eligible for prune when CRIT is hit)
PRUNE_SONARR_OLDER_THAN_DAYS=60

# Safety: only prune ended series
PRUNE_SONARR_ENDED_ONLY=1

# -------------------------
# Radarr
# -------------------------
RADARR_URL="http://192.168.5.81:7878"
RADARR_API_KEY="REPLACE_ME"

PRUNE_RADARR_ENABLE=1
PRUNE_RADARR_OLDER_THAN_DAYS=120          # based on Radarr "added" date
PRUNE_RADARR_UNMONITORED_ONLY=1           # SAFETY: only delete unmonitored movies
PRUNE_RADARR_ADD_EXCLUSION=1              # prevent re-download
PRUNE_RADARR_DELETE_FILES=1               # delete movie files from disk

# -------------------------
# Global safety switch
# -------------------------
DRY_RUN=0   # 1 = log only, 0 = actually delete

# -------------------------
# Alerts (ntfy)
# -------------------------
NTFY_ENABLE=0
NTFY_URL="https://ntfy.sh"
NTFY_TOPIC="arr-disk-alerts"   # use a random/private topic

# Log file
LOG="/var/log/media_prune.log"

# =========================
# HELPERS
# =========================
ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(ts)] $*" | tee -a "$LOG" >/dev/null; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { log "ERROR: missing required command: $1"; exit 1; }
}

disk_used_pct() {
  df -P "$MOUNT" | awk 'NR==2{gsub("%","",$5); print $5}'
}

send_ntfy() {
  local title="$1"
  local msg="$2"
  if [[ "$NTFY_ENABLE" -eq 1 ]]; then
    curl -fsS \
      -H "Title: ${title}" \
      -H "Priority: high" \
      -d "${msg}" \
      "${NTFY_URL}/${NTFY_TOPIC}" >/dev/null || true
  fi
}

# =========================
# SONARR PRUNE (API)
# =========================
sonarr_get_series() {
  curl -fsS -H "X-Api-Key: $SONARR_API_KEY" "$SONARR_URL/api/v3/series"
}

sonarr_get_episodes_for_series() {
  local series_id="$1"
  curl -fsS -H "X-Api-Key: $SONARR_API_KEY" "$SONARR_URL/api/v3/episode?seriesId=$series_id"
}

sonarr_get_episodefiles_for_series() {
  local series_id="$1"
  curl -fsS -H "X-Api-Key: $SONARR_API_KEY" "$SONARR_URL/api/v3/episodefile?seriesId=$series_id"
}

sonarr_delete_episode_file() {
  local episode_file_id="$1"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY_RUN: would delete Sonarr episodeFileId=$episode_file_id"
    return 0
  fi
  curl -fsS -X DELETE -H "X-Api-Key: $SONARR_API_KEY" \
    "$SONARR_URL/api/v3/episodefile/$episode_file_id" >/dev/null
  log "Deleted Sonarr episodeFileId=$episode_file_id"
}

prune_sonarr_old_seasons() {
  require_cmd jq
  require_cmd curl

  if [[ -z "${SONARR_API_KEY:-}" || "$SONARR_API_KEY" == "REPLACE_WITH_SONARR_API_KEY" ]]; then
    log "ERROR: SONARR_API_KEY not set. Skipping Sonarr prune."
    return 0
  fi

  local cutoff_epoch
  cutoff_epoch="$(date -d "-${PRUNE_SONARR_OLDER_THAN_DAYS} days" +%s)"
  log "Starting Sonarr prune: older_than_days=${PRUNE_SONARR_OLDER_THAN_DAYS}, cutoff_epoch=${cutoff_epoch}, ended_only=${PRUNE_SONARR_ENDED_ONLY}, dry_run=${DRY_RUN}"

  local series_json
  series_json="$(sonarr_get_series)"

  echo "$series_json" | jq -r '.[] | "\(.id)\t\(.title)\t\(.status)"' | \
  while IFS=$'\t' read -r sid title status; do
    if [[ "$PRUNE_SONARR_ENDED_ONLY" -eq 1 && "$status" != "ended" ]]; then
      continue
    fi

    local eps_json files_json
    eps_json="$(sonarr_get_episodes_for_series "$sid")"
    files_json="$(sonarr_get_episodefiles_for_series "$sid")"

    # Map: seasonNumber -> list of episodeFileIds (hasFile=true)
    # Then for each season, compute newest dateAdded among those episode files.
    echo "$eps_json" | jq -r '
      [ .[] | select(.hasFile==true) | {season:.seasonNumber, episodeFileId:.episodeFileId} ]
      | group_by(.season)
      | map({season:.[0].season, ids:(map(.episodeFileId)|unique)})
      | .[]
      | "\(.season)\t\(.ids|join(","))"
    ' | while IFS=$'\t' read -r season ids_csv; do
      [[ -z "$season" || -z "$ids_csv" ]] && continue

      local newest_epoch
      newest_epoch="$(echo "$files_json" | jq -r --arg ids "$ids_csv" '
        ($ids | split(",") | map(tonumber)) as $want
        | [ .[]
            | select(.id as $id | $want | index($id))
            | .dateAdded
          ]
        | map(fromdateiso8601)
        | (max // 0)
      ')"

      if [[ "$newest_epoch" -le "$cutoff_epoch" ]]; then
        log "Pruning Sonarr: series='$title' season=$season newest_import_epoch=$newest_epoch <= cutoff=$cutoff_epoch"
        IFS=',' read -ra ids_arr <<<"$ids_csv"
        for fid in "${ids_arr[@]}"; do
          sonarr_delete_episode_file "$fid"
        done
      fi
    done
  done

  log "Sonarr prune completed."
}

# =========================
# RADARR PRUNE (API)
# =========================
radarr_get_movies() {
  curl -fsS -H "X-Api-Key: $RADARR_API_KEY" "$RADARR_URL/api/v3/movie"
}

radarr_delete_movie() {
  local movie_id="$1"
  local title="$2"

  local qs=()
  if [[ "$PRUNE_RADARR_DELETE_FILES" -eq 1 ]]; then
    qs+=("deleteFiles=true")
  else
    qs+=("deleteFiles=false")
  fi

  if [[ "$PRUNE_RADARR_ADD_EXCLUSION" -eq 1 ]]; then
    qs+=("addExclusion=true")
  fi

  local qstr
  qstr="$(IFS='&'; echo "${qs[*]}")"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY_RUN: would delete Radarr movieId=$movie_id title='$title' (${qstr})"
    return 0
  fi

  curl -fsS -X DELETE -H "X-Api-Key: $RADARR_API_KEY" \
    "$RADARR_URL/api/v3/movie/${movie_id}?${qstr}" >/dev/null

  log "Deleted Radarr movieId=$movie_id title='$title'"
}

prune_radarr_old_movies() {
  require_cmd jq
  require_cmd curl

  if [[ "$PRUNE_RADARR_ENABLE" -ne 1 ]]; then
    log "Radarr prune disabled."
    return 0
  fi

  if [[ -z "${RADARR_API_KEY:-}" || "$RADARR_API_KEY" == "REPLACE_WITH_RADARR_API_KEY" ]]; then
    log "ERROR: RADARR_API_KEY not set. Skipping Radarr prune."
    return 0
  fi

  local cutoff_epoch
  cutoff_epoch="$(date -d "-${PRUNE_RADARR_OLDER_THAN_DAYS} days" +%s)"
  log "Starting Radarr prune: older_than_days=${PRUNE_RADARR_OLDER_THAN_DAYS}, cutoff_epoch=${cutoff_epoch}, unmonitored_only=${PRUNE_RADARR_UNMONITORED_ONLY}, dry_run=${DRY_RUN}"

  local movies_json
  movies_json="$(radarr_get_movies)"

  echo "$movies_json" | jq -r '
    .[]
    | select(.hasFile==true)
    | "\(.id)\t\(.title)\t\(.monitored)\t\(.added)\t\(.path)"
  ' | while IFS=$'\t' read -r mid title monitored added path; do
    if [[ "$PRUNE_RADARR_UNMONITORED_ONLY" -eq 1 && "$monitored" == "true" ]]; then
      continue
    fi

    local added_epoch
    added_epoch="$(date -d "$added" +%s 2>/dev/null || echo 0)"

    if [[ "$added_epoch" -le "$cutoff_epoch" ]]; then
      log "Pruning Radarr: movie='$title' monitored=$monitored added=$added path=$path"
      radarr_delete_movie "$mid" "$title"
    fi
  done

  log "Radarr prune completed."
}

# =========================
# MAIN
# =========================
main() {
  mkdir -p "$(dirname "$LOG")"
  touch "$LOG"

  local used
  used="$(disk_used_pct)"
  log "Disk usage on $MOUNT: ${used}%"

  if [[ "$used" -ge "$WARN_PCT" ]]; then
    send_ntfy "ARR Disk Warning (${used}%)" "Disk usage on ${MOUNT} is ${used}% (warn=${WARN_PCT}%, crit=${CRIT_PCT}%)."
  fi

  if [[ "$used" -ge "$CRIT_PCT" ]]; then
    log "CRITICAL: usage ${used}% >= ${CRIT_PCT}%. Starting auto-prune (Sonarr+Radarr)."
    send_ntfy "ARR Disk Critical (${used}%)" "Starting auto-prune (Sonarr+Radarr) because disk usage on ${MOUNT} is ${used}%."

    prune_sonarr_old_seasons
    prune_radarr_old_movies

    used="$(disk_used_pct)"
    log "Post-prune disk usage on $MOUNT: ${used}%"
    send_ntfy "ARR Disk Post-Prune (${used}%)" "After auto-prune, disk usage on ${MOUNT} is ${used}%."
  fi
}

main "$@"
