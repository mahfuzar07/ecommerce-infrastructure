# Ecommerce Infrastructure (`ecommerce-infrastructure`)

Production Docker Compose orchestration, Nginx TLS reverse proxy, Certbot, and backup/restore runbooks for API, Storefront, and Admin Portal.

## Deployment & Operations
- **Immutable CD**: Triggered via root `.github/workflows/deploy.yml` using `IMAGE_TAG` from `.github/workflows/docker-publish.yml`.
- **Deploy Script**: `bash ecommerce-infrastructure/scripts/deploy.sh` (supports `--env-file`, runs `prisma migrate deploy`, and gates on `/health/ready`).
- **Database Backup & Restore**:
  - Backup: `bash ecommerce-infrastructure/scripts/backup-db.sh`
  - Restore: `bash ecommerce-infrastructure/scripts/restore-db.sh <backup-file> --confirm`
- **TLS Renewal**: Reload Nginx after Certbot renewal via `docker compose -f ecommerce-infrastructure/docker-compose.prod.yml exec -T nginx nginx -s reload`.
