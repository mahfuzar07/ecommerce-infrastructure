#!/usr/bin/env bash
# =============================================================================
# Automated Zero-Downtime Deployment Script (Immutable Image + Readiness Gate)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$INFRA_DIR")"
COMPOSE_FILE="$INFRA_DIR/docker-compose.prod.yml"
ENV_FILE="${ENV_FILE:-$INFRA_DIR/.env.production}"

cd "$ROOT_DIR"

COMPOSE_ARGS=(-f "$COMPOSE_FILE")
if [ -f "$ENV_FILE" ]; then
  COMPOSE_ARGS+=(--env-file "$ENV_FILE")
fi

echo "=========================================================="
echo "Starting Production Deployment"
echo "=========================================================="

# 1. Pull pre-built images when IMAGE_TAG is provided; otherwise build locally
if [ -n "${IMAGE_TAG:-}" ]; then
  echo "Pulling immutable GHCR images (tag: $IMAGE_TAG)..."
  docker compose "${COMPOSE_ARGS[@]}" pull
else
  echo "Building application Docker images..."
  docker compose "${COMPOSE_ARGS[@]}" build
fi

# 2. Ensure stateful backing services are healthy first
echo "Starting PostgreSQL and Redis..."
docker compose "${COMPOSE_ARGS[@]}" up -d postgres redis

# 3. Run Prisma forward migrations BEFORE starting new API code
echo "Applying database migrations via Prisma..."
docker compose "${COMPOSE_ARGS[@]}" run --rm app npx prisma migrate deploy

# 4. Update application & proxy containers
echo "Updating application and proxy containers..."
docker compose "${COMPOSE_ARGS[@]}" up -d

# 5. Readiness check on /health/ready
echo "Verifying API readiness..."
for i in $(seq 1 15); do
  if docker compose "${COMPOSE_ARGS[@]}" exec -T app node -e "fetch('http://127.0.0.1:5000/health/ready').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"; then
    echo "API /health/ready passed."
    break
  fi
  if [ "$i" -eq 15 ]; then
    echo "ERROR: API failed /health/ready readiness gate!"
    exit 1
  fi
  sleep 2
done

# 6. Clean up old/dangling Docker images
docker image prune -f

echo "=========================================================="
echo "Deployment Finished Successfully!"
docker compose "${COMPOSE_ARGS[@]}" ps
echo "=========================================================="
