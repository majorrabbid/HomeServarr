#!/bin/sh
# ─────────────────────────────────────────────────────────────
# Jarvis local launcher
# Run from this directory: ./run-local.sh
# ─────────────────────────────────────────────────────────────
set -e
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "ERROR: .env not found. Copy .env.example → .env and fill in values."
  exit 1
fi

echo "Building and starting Jarvis..."
docker compose up --build -d

echo ""
echo "Signal registration:"
echo "  1. Set JARVIS_NUMBER in .env to your Google Voice number (+1XXXXXXXXXX)"
echo "  2. Register:  curl -X POST http://localhost:8080/v1/register/\$JARVIS_NUMBER"
echo "  3. Verify:    curl -X POST http://localhost:8080/v1/register/\$JARVIS_NUMBER/verify/CODE"
echo "  (Replace CODE with the SMS code you receive)"
echo ""
echo "Or link to an existing Signal account:"
echo "  curl 'http://localhost:8080/v1/qrcodelink?device_name=Jarvis' | qrencode -t ANSIUTF8"
echo "  Scan QR in your Signal app → Linked Devices → Link New Device"
echo ""
echo "Useful commands:"
echo "  docker compose logs -f jarvis    # Jarvis logs"
echo "  docker compose logs -f signal    # signal-cli logs"
echo "  docker compose down              # Stop everything"
