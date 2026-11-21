# Production Infrastructure & Deployment Guide

This directory (`ecommerce-infrastructure/`) contains all Docker Compose, Nginx reverse proxy, SSL Certbot, CI/CD, and automation scripts to run the entire Twinkle Bud Ecommerce ecosystem (`ecommerce-nest-api`, `ecommerce-store`, `ecommerce-portal-new`, PostgreSQL, and Redis) on a single VPS.

---

## 📁 Directory Architecture

```text
├── ecommerce-nest-api/
│   ├── Dockerfile
│   └── docker/
│       ├── docker-compose.dev.yml    # API + DB + Redis + PgAdmin (Local Dev)
│       └── docker-compose.prod.yml   # API + DB + Redis (Standalone Prod)
│
├── ecommerce-store/
│   ├── Dockerfile
│   └── docker-compose.prod.yml       # Storefront (Standalone Prod)
│
├── ecommerce-portal-new/
│   ├── Dockerfile
│   └── docker-compose.prod.yml       # Admin Portal (Standalone Prod)
│
└── ecommerce-infrastructure/         # Master Reverse Proxy & Operations
    ├── docker-compose.prod.yml       # Uses `include:` to orchestrate all 3 apps + Nginx + Certbot
    ├── .env.production.example       # Central environment variables reference
    ├── nginx/
    │   ├── nginx.conf                # Core Nginx performance, gzip & proxy configuration
    │   └── conf.d/
    │       ├── default.conf          # Port 80 HTTP -> HTTPS redirect & ACME challenge
    │       ├── store.conf            # Storefront proxy (yourdomain.com) + cache headers
    │       ├── portal.conf           # Admin portal proxy (admin.yourdomain.com)
    │       └── api.conf              # NestJS API proxy (api.yourdomain.com) + SSE support
    └── scripts/
        ├── vps-setup.sh              # One-click Ubuntu VPS setup (Docker, UFW, Swap)
        ├── init-letsencrypt.sh       # SSL bootstrapping script (handles dummy cert bootstrap)
        ├── deploy.sh                 # Zero-downtime build, update, & migration script
        └── backup-db.sh              # Daily automated PostgreSQL backup
```

---

## 🎯 Dual Execution Modes

### Mode A: Running Individual Projects Standalone

If you want to run or test only a single project:

* **Backend API & Database only:**
  ```bash
  cd ecommerce-nest-api
  docker compose -f docker/docker-compose.prod.yml up --build -d
  ```
* **Storefront only:**
  ```bash
  cd ecommerce-store
  docker compose -f docker-compose.prod.yml up --build -d
  ```
* **Admin Portal only:**
  ```bash
  cd ecommerce-portal-new
  docker compose -f docker-compose.prod.yml up --build -d
  ```

---

### Mode B: Master All-in-One Orchestration (Production VPS)

On your production VPS, run the master orchestrator in `ecommerce-infrastructure/`. It uses Docker Compose `include:` to pull in all three projects, links them into `ecommerce_network`, and exposes them through Nginx with SSL:

```bash
cd ecommerce-infrastructure
docker compose -f docker-compose.prod.yml up --build -d
```

---

## 🚀 Step-by-Step VPS Deployment

### 1. Initial VPS Setup
On your freshly provisioned Ubuntu 22.04 / 24.04 VPS:

```bash
# Clone the repository
sudo mkdir -p /var/www/ecommerce
sudo chown -R $USER:$USER /var/www/ecommerce
cd /var/www/ecommerce
git clone <your-git-repo-url> .

# Make scripts executable
chmod +x ecommerce-infrastructure/scripts/*.sh

# Run VPS setup (Updates system, configures 4GB swap space, installs Docker, enables UFW)
./ecommerce-infrastructure/scripts/vps-setup.sh
```

### 2. Configure Environment Variables
Create your production `.env.production` files:
* Backend: `ecommerce-nest-api/.env.production`
* Storefront: `ecommerce-store/.env.production`
* Portal: `ecommerce-portal-new/.env.production`

### 3. Bootstrap SSL Certificates
Edit `ecommerce-infrastructure/scripts/init-letsencrypt.sh` with your domain names and email address, then execute:
```bash
./ecommerce-infrastructure/scripts/init-letsencrypt.sh
```

### 4. Deploy & Run Migrations
Run the zero-downtime deployment script:
```bash
./ecommerce-infrastructure/scripts/deploy.sh
```

---

## 🛠️ Management Commands

```bash
# Check status of all containers
docker compose -f ecommerce-infrastructure/docker-compose.prod.yml ps

# View live logs
docker compose -f ecommerce-infrastructure/docker-compose.prod.yml logs -f

# View specific app logs
docker compose -f ecommerce-infrastructure/docker-compose.prod.yml logs -f app
docker compose -f ecommerce-infrastructure/docker-compose.prod.yml logs -f store
docker compose -f ecommerce-infrastructure/docker-compose.prod.yml logs -f portal
docker compose -f ecommerce-infrastructure/docker-compose.prod.yml logs -f nginx

# Create manual PostgreSQL database backup
./ecommerce-infrastructure/scripts/backup-db.sh
```
