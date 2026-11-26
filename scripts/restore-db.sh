#!/usr/bin/env bash
# =============================================================================
# PostgreSQL Safe Restore Script
# Supports plain .sql.gz and OpenSSL-encrypted .sql.gz.enc backups.
# Requires explicit --confirm flag to avoid accidental database overwrites.
# Usage:
#   ./restore-db.sh /path/to/backup.sql.gz --confirm
#   BACKUP_ENCRYPTION_PASSPHRASE=... ./restore-db.sh /path/to/backup.sql.gz.enc --confirm
# =============================================================================
set -euo pipefail

if [ "$#" -lt 2 ] || [ "$2" != "--confirm" ]; then
  echo "Usage: $0 <backup_file.(sql.gz|sql.gz.enc)> --confirm" >&2
  echo "Aborted: --confirm flag is required for database restore." >&2
  exit 1
fi

BACKUP_FILE="$1"
if [ ! -f "$BACKUP_FILE" ] || [ ! -s "$BACKUP_FILE" ]; then
  echo "❌ Backup file not found or empty: $BACKUP_FILE" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "${INFRA_DIR}/.env.production" ]; then
  set -a
  # shellcheck disable=SC1091
  source "${INFRA_DIR}/.env.production"
  set +a
fi

TARGET_USER="${POSTGRES_USER:-ecommerce_user}"
TARGET_DB="${POSTGRES_DB:-ecommerce_db}"

echo "🔄 Restoring PostgreSQL database '${TARGET_DB}' from '${BACKUP_FILE}'..."

if [[ "$BACKUP_FILE" == *.enc ]]; then
  if [ -z "${BACKUP_ENCRYPTION_PASSPHRASE:-}" ]; then
    echo "❌ BACKUP_ENCRYPTION_PASSPHRASE must be set to decrypt .enc backup" >&2
    exit 1
  fi
  openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 \
    -in "$BACKUP_FILE" \
    -pass env:BACKUP_ENCRYPTION_PASSPHRASE \
    | gunzip \
    | docker compose -f "${INFRA_DIR}/docker-compose.prod.yml" exec -T postgres \
        psql -v ON_ERROR_STOP=1 -U "$TARGET_USER" "$TARGET_DB"
else
  gunzip -c "$BACKUP_FILE" \
    | docker compose -f "${INFRA_DIR}/docker-compose.prod.yml" exec -T postgres \
        psql -v ON_ERROR_STOP=1 -U "$TARGET_USER" "$TARGET_DB"
fi

echo "✅ Restore completed successfully."
