#!/usr/bin/env bash
# =============================================================================
# Automated Zero-Downtime Deployment Script
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$INFRA_DIR")"

cd "$ROOT_DIR"

echo "=========================================================="
echo "🚀 Starting Production Deployment"
echo "=========================================================="

# 1. Pull latest code from Git (if in a Git repository)
if [ -d .git ]; then
    echo "📥 Pulling latest git changes..."
    git pull origin main --rebase
fi

# 2. Build Docker containers
echo "🏗️  Building application Docker images..."
docker compose -f ecommerce-infrastructure/docker-compose.prod.yml build

# 3. Ensure stateful backing services are healthy first
echo "🗄️  Starting PostgreSQL and Redis..."
docker compose -f ecommerce-infrastructure/docker-compose.prod.yml up -d postgres redis

# 4. Run Prisma forward migrations BEFORE starting new API code
echo "🔄 Applying database migrations via Prisma..."
docker compose -f ecommerce-infrastructure/docker-compose.prod.yml run --rm app npx prisma migrate deploy

# 5. Start or update application & proxy containers
echo "🚀 Updating application and proxy containers..."
docker compose -f ecommerce-infrastructure/docker-compose.prod.yml up -d

# 5. Clean up old/dangling Docker images to save disk space
echo "🧹 Pruning dangling docker images..."
docker image prune -f

echo "=========================================================="
echo "🎉 Deployment Finished Successfully!"
docker compose -f ecommerce-infrastructure/docker-compose.prod.yml ps
echo "=========================================================="
