#!/usr/bin/env bash
# =============================================================================
# Automated PostgreSQL Daily Backup Script
# Keeps backups for 7 days. Can be configured with crontab:
# 0 3 * * * /path/to/ecommerce-infrastructure/scripts/backup-db.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${INFRA_DIR}/backups/postgres"

mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/ecommerce_db_backup_${TIMESTAMP}.sql.gz"

echo "💾 Creating PostgreSQL backup: $BACKUP_FILE ..."

docker compose -f "${INFRA_DIR}/docker-compose.prod.yml" exec -T postgres \
    pg_dump -U "${POSTGRES_USER:-ecommerce_user}" "${POSTGRES_DB:-ecommerce_db}" | gzip > "$BACKUP_FILE"

echo "✅ Backup successfully created ($(du -h "$BACKUP_FILE" | cut -f1))"

# Keep last 7 days of backups
echo "🧹 Removing backups older than 7 days..."
find "$BACKUP_DIR" -type f -name "*.sql.gz" -mtime +7 -delete

echo "Done."
