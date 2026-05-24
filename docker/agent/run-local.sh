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
echo "Signal registration (Australian SIM):"
echo "  Your Jarvis SIM number in E.164 format: drop the leading 0, prefix +61"
echo "  e.g.  0412 345 678  →  +61412345678"
echo ""
echo "  1. Set JARVIS_NUMBER=+61XXXXXXXXX in .env (the dedicated Jarvis SIM)"
echo "  2. Register — signal-cli sends an SMS to that physical SIM:"
echo "       curl -X POST http://localhost:8080/v1/register/+61XXXXXXXXX"
echo "  3. Check the Jarvis SIM for the SMS verification code, then:"
echo "       curl -X POST http://localhost:8080/v1/register/+61XXXXXXXXX/verify/CODE"
echo "  4. Set ALLOWED_SENDERS=+61XXXXXXXXX in .env (your personal mobile)"
echo "  5. Restart Jarvis: docker compose restart jarvis"
echo ""
echo "  Once registered, text the Jarvis number from your personal Signal app."
echo ""
echo "Useful commands:"
echo "  docker compose logs -f jarvis    # Jarvis logs"
echo "  docker compose logs -f signal    # signal-cli logs"
echo "  docker compose down              # Stop everything"
