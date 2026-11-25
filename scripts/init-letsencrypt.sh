#!/usr/bin/env bash
# =============================================================================
# Automated Let's Encrypt SSL Bootstrapping Script
# Solves the chicken-and-egg problem where Nginx cannot start without SSL certs
# =============================================================================
set -euo pipefail

# Change directory to infrastructure root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"
cd "$INFRA_DIR"

# Configuration - replace with your actual domains and contact email
DOMAINS=("yourdomain.com" "www.yourdomain.com" "admin.yourdomain.com" "api.yourdomain.com")
PRIMARY_DOMAIN="${DOMAINS[0]}"
EMAIL="admin@yourdomain.com"
STAGING=0 # Set to 1 if testing to avoid Let's Encrypt rate limits

echo "=========================================================="
echo "🔐 Setting up SSL Certificates for: ${DOMAINS[*]}"
echo "=========================================================="

CERT_LIVE_DIR="/etc/letsencrypt/live/${PRIMARY_DOMAIN}"

if docker compose -f docker-compose.prod.yml run --rm --entrypoint "test -d ${CERT_LIVE_DIR}" certbot 2>/dev/null; then
    read -p "Existing certificate found for ${PRIMARY_DOMAIN} in certbot_conf volume. Continue and replace? (y/N) " decision
    if [ "$decision" != "y" ] && [ "$decision" != "Y" ]; then
        echo "Exiting without changes."
        exit 0
    fi
fi

# 1. Create dummy certificate inside the named certbot_conf volume so Nginx can start
echo "Creating dummy certificates inside certbot_conf volume for Nginx initial boot..."
docker compose -f docker-compose.prod.yml run --rm --entrypoint "\
    sh -c 'mkdir -p ${CERT_LIVE_DIR} /var/www/certbot && \
    openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
      -keyout ${CERT_LIVE_DIR}/privkey.pem \
      -out ${CERT_LIVE_DIR}/fullchain.pem \
      -subj /CN=localhost'" certbot

# 2. Start Nginx container
echo "Starting Nginx..."
docker compose -f docker-compose.prod.yml up -d nginx

# 3. Delete dummy certificates from the named volume before requesting real ones
echo "Removing dummy certificates..."
docker compose -f docker-compose.prod.yml run --rm --entrypoint "\
    rm -rf /etc/letsencrypt/live/${PRIMARY_DOMAIN} \
           /etc/letsencrypt/archive/${PRIMARY_DOMAIN} \
           /etc/letsencrypt/renewal/${PRIMARY_DOMAIN}.conf" certbot

# 4. Request actual Let's Encrypt certificates using Certbot
echo "🌐 Requesting real SSL certificates from Let's Encrypt..."
domain_args=""
for domain in "${DOMAINS[@]}"; do
    domain_args="$domain_args -d $domain"
done

staging_arg=""
if [ "$STAGING" != "0" ]; then
    staging_arg="--staging"
fi

docker compose -f docker-compose.prod.yml run --rm --entrypoint "\
    certbot certonly --webroot -w /var/www/certbot \
    $staging_arg \
    $domain_args \
    --email $EMAIL \
    --rsa-key-size 4096 \
    --agree-tos \
    --non-interactive \
    --force-renewal" certbot

# 5. Reload Nginx to load the newly issued certificates
echo "🔄 Reloading Nginx with authentic SSL certificates..."
docker compose -f docker-compose.prod.yml exec nginx nginx -s reload

echo "=========================================================="
echo "✅ SSL Certificates have been successfully issued and loaded!"
echo "Certbot container will now automatically renew them every 12 hours."
echo "=========================================================="
