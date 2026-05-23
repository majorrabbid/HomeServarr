#!/bin/sh
set -e

cd "$(dirname "$0")"

docker compose up --build -d

echo "Jarvis local container started."
echo "To see logs: docker compose logs -f"
echo "To run Jarvis commands inside the container:"
echo "  docker exec -it homeservarr-jarvis-agent /usr/local/bin/homeservarr-agent"
echo "To stop it: docker compose down"
