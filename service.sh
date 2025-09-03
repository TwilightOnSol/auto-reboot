#!/bin/bash

set -euo pipefail

# Variables
CLOUDFLARED_BIN="/usr/local/bin/cloudflared"
SERVICE_FILE="/etc/systemd/system/cloudflared.service"
GPG_KEYRING="/usr/share/keyrings/cloudflare-main.gpg"
REPO_LIST="/etc/apt/sources.list.d/cloudflared.list"

# 1. Install prerequisites
echo "Installing prerequisites..."
sudo apt-get update
sudo apt-get install -y curl apt-transport-https

# 2. Add Cloudflare GPG key and repo if not already present
if [ ! -f "$GPG_KEYRING" ]; then
  echo "Adding Cloudflare GPG key..."
  sudo mkdir -p --mode=0755 /usr/share/keyrings
  curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee "$GPG_KEYRING" >/dev/null
else
  echo "Cloudflare GPG key already exists."
fi

if [ ! -f "$REPO_LIST" ]; then
  echo "Adding Cloudflare apt repository..."
  echo "deb [signed-by=$GPG_KEYRING] https://pkg.cloudflare.com/cloudflared any main" | sudo tee "$REPO_LIST"
else
  echo "Cloudflare apt repository already exists."
fi

# 3. Update and install cloudflared if not installed
if ! command -v cloudflared >/dev/null 2>&1; then
  echo "Installing cloudflared..."
  sudo apt-get update
  sudo apt-get install -y cloudflared
else
  echo "cloudflared is already installed."
fi

# 4. Create or overwrite systemd service file with robust auto-restart settings
echo "Creating systemd service file at $SERVICE_FILE..."

sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Cloudflare Tunnel Agent
After=network.target

[Service]
ExecStart=$(command -v cloudflared) tunnel run
Restart=on-failure
RestartSec=5s
StartLimitBurst=5
StartLimitIntervalSec=60
User=nobody
# Adjust User if needed

[Install]
WantedBy=multi-user.target
EOF

# 5. Reload systemd, enable and start the service
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Enabling cloudflared service to start on boot..."
sudo systemctl enable cloudflared

echo "Starting cloudflared service..."
sudo systemctl restart cloudflared

# 6. Check service status
echo "Checking cloudflared service status..."
sudo systemctl status cloudflared --no-pager

echo "Setup complete. cloudflared will auto-restart on failure."
