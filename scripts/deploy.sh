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

# 3. Start or update containers
echo "🔄 Starting application containers..."
docker compose -f ecommerce-infrastructure/docker-compose.prod.yml up -d

# 4. Wait for database & API to be ready, then run Prisma migrations
echo "🗄️  Applying database migrations via Prisma..."
docker compose -f ecommerce-infrastructure/docker-compose.prod.yml exec -T app npx prisma migrate deploy

# 5. Clean up old/dangling Docker images to save disk space
echo "🧹 Pruning dangling docker images..."
docker image prune -f

echo "=========================================================="
echo "🎉 Deployment Finished Successfully!"
docker compose -f ecommerce-infrastructure/docker-compose.prod.yml ps
echo "=========================================================="
