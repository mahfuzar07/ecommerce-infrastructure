#!/usr/bin/env bash
# =============================================================================
# Automated PostgreSQL Daily Backup Script
# Supports optional OpenSSL AES-256 encryption and S3/R2 off-site upload.
# Keeps local backups for 7 days. Crontab example:
# 0 3 * * * /path/to/ecommerce-infrastructure/scripts/backup-db.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="${INFRA_DIR}/backups/postgres"

if [ -f "${INFRA_DIR}/.env.production" ]; then
  set -a
  # shellcheck disable=SC1091
  source "${INFRA_DIR}/.env.production"
  set +a
fi

mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RAW_BACKUP="${BACKUP_DIR}/ecommerce_db_backup_${TIMESTAMP}.sql.gz"
FINAL_BACKUP="$RAW_BACKUP"

echo "💾 Creating PostgreSQL backup: $RAW_BACKUP ..."

docker compose -f "${INFRA_DIR}/docker-compose.prod.yml" exec -T postgres \
    pg_dump -U "${POSTGRES_USER:-ecommerce_user}" "${POSTGRES_DB:-ecommerce_db}" | gzip > "$RAW_BACKUP"

if [ ! -s "$RAW_BACKUP" ]; then
  echo "❌ Backup file is missing or empty: $RAW_BACKUP" >&2
  rm -f "$RAW_BACKUP"
  exit 1
fi

if [ -n "${BACKUP_ENCRYPTION_PASSPHRASE:-}" ]; then
  if ! command -v openssl >/dev/null 2>&1; then
    echo "❌ openssl is required when BACKUP_ENCRYPTION_PASSPHRASE is set" >&2
    exit 1
  fi
  FINAL_BACKUP="${RAW_BACKUP}.enc"
  openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt \
    -in "$RAW_BACKUP" \
    -out "$FINAL_BACKUP" \
    -pass env:BACKUP_ENCRYPTION_PASSPHRASE
  rm -f "$RAW_BACKUP"
  echo "🔐 Encrypted backup created: $FINAL_BACKUP"
fi

echo "✅ Backup ready: $FINAL_BACKUP ($(du -h "$FINAL_BACKUP" | cut -f1))"

if [ -n "${BACKUP_S3_URI:-}" ]; then
  S3_DEST="${BACKUP_S3_URI%/}/$(basename "$FINAL_BACKUP")"
  if command -v aws >/dev/null 2>&1; then
    aws s3 cp "$FINAL_BACKUP" "$S3_DEST"
    echo "☁️ Uploaded backup via AWS CLI to $S3_DEST"
  elif command -v rclone >/dev/null 2>&1; then
    rclone copy "$FINAL_BACKUP" "$BACKUP_S3_URI"
    echo "☁️ Uploaded backup via rclone to $BACKUP_S3_URI"
  else
    echo "⚠️ BACKUP_S3_URI is set, but neither aws nor rclone CLI is installed." >&2
    exit 1
  fi
fi

# Keep last 7 days of local backups
echo "🧹 Removing backups older than 7 days..."
find "$BACKUP_DIR" -type f \( -name "*.sql.gz" -o -name "*.sql.gz.enc" \) -mtime +7 -delete

echo "Done."
