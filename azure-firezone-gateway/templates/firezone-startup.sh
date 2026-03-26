#!/bin/bash
# Firezone Gateway Installation Script for Azure VM
set -e

exec > >(tee -a /var/log/firezone-startup.log)
exec 2>&1

echo "=== Firezone Gateway setup started at $(date) ==="

# Variables injected by Terraform templatefile()
FIREZONE_TOKEN="${firezone_token}"
FIREZONE_ID="${firezone_id}"
LOG_LEVEL="${log_level}"

# Validate token is not empty or placeholder
if [ -z "$FIREZONE_TOKEN" ] || [ "$FIREZONE_TOKEN" = "PASTE_YOUR_FRESH_TOKEN_HERE" ]; then
  echo "ERROR: FIREZONE_TOKEN is missing or is a placeholder. Aborting."
  exit 1
fi

if [ -z "$FIREZONE_ID" ]; then
  echo "ERROR: FIREZONE_ID is missing. Aborting."
  exit 1
fi

echo "Token and ID validated."

# System update
apt-get update -y
apt-get install -y curl ca-certificates iptables

# Enable IP forwarding (required for WireGuard routing)
cat >> /etc/sysctl.conf <<'EOF'
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.ipv4.conf.all.src_valid_mark = 1
EOF
sysctl -p

# Install Docker using official convenience script
curl -fsSL https://get.docker.com | sh
systemctl enable docker
systemctl start docker

# Wait for Docker daemon to be ready
echo "Waiting for Docker daemon..."
for i in $(seq 1 15); do
  docker info >/dev/null 2>&1 && echo "Docker ready." && break
  echo "  attempt $i/15..."
  sleep 4
done

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker daemon did not start in time."
  exit 1
fi

# Pull Firezone gateway image with retry
echo "Pulling Firezone gateway image..."
for attempt in $(seq 1 3); do
  timeout 300 docker pull ghcr.io/firezone/gateway:1 && break
  echo "  Pull attempt $attempt failed, retrying in 10s..."
  sleep 10
  if [ "$attempt" -eq 3 ]; then
    echo "ERROR: Failed to pull Firezone image after 3 attempts."
    exit 1
  fi
done

# Remove any existing container
docker rm -f firezone-gateway 2>/dev/null || true

# Run Firezone gateway container (exact command from Firezone portal)
echo "Starting Firezone gateway container..."
docker run -d \
  --restart=unless-stopped \
  --pull=always \
  --health-cmd="ip link | grep tun-firezone" \
  --name=firezone-gateway \
  --cap-add=NET_ADMIN \
  --sysctl net.ipv4.ip_forward=1 \
  --sysctl net.ipv4.conf.all.src_valid_mark=1 \
  --sysctl net.ipv6.conf.all.disable_ipv6=0 \
  --sysctl net.ipv6.conf.all.forwarding=1 \
  --sysctl net.ipv6.conf.default.forwarding=1 \
  --device="/dev/net/tun:/dev/net/tun" \
  --env FIREZONE_ID="$FIREZONE_ID" \
  --env FIREZONE_TOKEN="$FIREZONE_TOKEN" \
  --env FIREZONE_NAME="$(hostname)" \
  --env RUST_LOG="$LOG_LEVEL" \
  ghcr.io/firezone/gateway:1

# Wait for container to stabilise and check logs for connection
echo "Waiting 45s for gateway to connect to Firezone control plane..."
sleep 45

if ! docker ps --filter "name=firezone-gateway" --filter "status=running" | grep -q firezone-gateway; then
  echo "ERROR: Firezone gateway container is not running."
  docker logs firezone-gateway
  exit 1
fi

echo "=== Firezone gateway container logs ==="
docker logs firezone-gateway --tail 40

# Check for successful connection in logs
if docker logs firezone-gateway 2>&1 | grep -qi "connected\|tunnel\|ready"; then
  echo "SUCCESS: Firezone gateway appears connected."
else
  echo "WARNING: Could not confirm connection in logs — check Firezone portal."
fi

# Health check HTTP service (used by Azure Load Balancer probe on port 8080)
apt-get install -y python3
mkdir -p /opt/firezone
echo "OK" > /opt/firezone/index.html

cat > /etc/systemd/system/firezone-health.service <<'EOF'
[Unit]
Description=Firezone Health Check HTTP Server
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/firezone
ExecStart=/usr/bin/python3 -m http.server 8080
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable firezone-health.service
systemctl start firezone-health.service

echo "=== Firezone Gateway setup completed at $(date) ==="
echo "Health check: http://$(hostname -I | awk '{print $1}'):8080"
echo "Logs: /var/log/firezone-startup.log"
echo "Container logs: docker logs firezone-gateway"
