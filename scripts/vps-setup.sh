#!/usr/bin/env bash
# =============================================================================
# Automated Ubuntu VPS Initial Setup Script
# =============================================================================
set -euo pipefail

echo "=========================================================="
echo "🚀 Starting Initial VPS Environment Setup"
echo "=========================================================="

# 1. Update & Upgrade System Packages
echo "📦 Updating system packages..."
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y curl git ufw fail2ban ca-certificates gnupg lsb-release

# 2. Configure 4GB Swap Space (Prevents out-of-memory during Next.js builds)
if [ ! -f /swapfile ]; then
    echo "🧠 Creating 4GB Swap Space..."
    sudo fallocate -l 4G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo "✅ Swap space enabled."
else
    echo "ℹ️  Swapfile already exists. Skipping."
fi

# 3. Install Docker Engine & Docker Compose Plugin
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker Engine..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm -f get-docker.sh
    sudo usermod -aG docker "$USER"
    echo "✅ Docker installed. (Note: you may need to log out and log back in for docker group to take effect)"
else
    echo "ℹ️  Docker is already installed."
fi

# 4. Configure UFW Firewall
echo "🛡️  Configuring UFW Firewall..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
echo "y" | sudo ufw enable

echo "=========================================================="
echo "🎉 VPS Setup Completed Successfully!"
echo "Docker is ready, firewall is active (ports 22, 80, 443 open), and 4GB Swap is enabled."
echo "=========================================================="
