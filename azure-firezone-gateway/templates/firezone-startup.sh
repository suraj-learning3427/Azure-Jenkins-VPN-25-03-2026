#!/bin/bash
# Firezone Gateway Installation Script for Azure VM
# Based on official Firezone gateway installation

set -e

# Log all output
exec > >(tee -a /var/log/firezone-startup.log)
exec 2>&1

echo "Starting Firezone Gateway setup..."
echo "Timestamp: $(date)"

# Variables from Terraform
FIREZONE_TOKEN="${firezone_token}"
LOG_LEVEL="${log_level}"

# Update system packages
echo "Updating system packages..."
apt-get update -y
apt-get upgrade -y

# Install required packages
echo "Installing required packages..."
apt-get install -y \
    curl \
    wget \
    gnupg \
    lsb-release \
    ca-certificates \
    software-properties-common \
    iptables \
    systemd-resolved

# Enable IP forwarding
echo "Enabling IP forwarding..."
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.conf
sysctl -p

# Install Docker
echo "Installing Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable Docker
systemctl enable docker
systemctl start docker

# Add user to docker group
usermod -aG docker azureuser

# Create Firezone directory
echo "Setting up Firezone..."
mkdir -p /opt/firezone
cd /opt/firezone

# Download Firezone gateway
echo "Downloading Firezone gateway..."
curl -fsSL https://github.com/firezone/firezone/releases/latest/download/gateway.yml -o docker-compose.yml

# Create environment file
cat > .env <<EOF
# Firezone Gateway Configuration
FIREZONE_TOKEN=$FIREZONE_TOKEN
FIREZONE_API_URL=wss://api.firezone.dev
FIREZONE_LOG_LEVEL=$LOG_LEVEL

# Network configuration
FIREZONE_INTERFACE=wg-firezone
FIREZONE_PORT=51820

# DNS configuration
FIREZONE_DNS_SERVERS=1.1.1.1,8.8.8.8
EOF

# Set proper permissions
chown -R azureuser:azureuser /opt/firezone
chmod 600 /opt/firezone/.env

# Configure firewall (UFW)
echo "Configuring firewall..."
ufw --force enable
ufw allow ssh
ufw allow 51820/udp  # WireGuard port
ufw allow 80/tcp     # HTTP for health checks
ufw allow 443/tcp    # HTTPS

# Configure systemd service for Firezone
cat > /etc/systemd/system/firezone-gateway.service <<EOF
[Unit]
Description=Firezone Gateway
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/firezone
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0
User=azureuser
Group=azureuser

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Firezone service
systemctl daemon-reload
systemctl enable firezone-gateway.service

# Start Firezone gateway
echo "Starting Firezone gateway..."
cd /opt/firezone
sudo -u azureuser docker compose up -d

# Wait for Firezone to start
echo "Waiting for Firezone gateway to start..."
sleep 30

# Check Firezone status
echo "Checking Firezone gateway status..."
if sudo -u azureuser docker compose ps | grep -q "Up"; then
    echo "Firezone gateway started successfully"
else
    echo "Warning: Firezone gateway may not have started properly"
    sudo -u azureuser docker compose logs
fi

# Create health check endpoint
echo "Setting up health check endpoint..."
cat > /opt/firezone/health-check.sh <<EOF
#!/bin/bash
# Simple health check for load balancer
if sudo -u azureuser docker compose ps | grep -q "Up"; then
    echo "OK"
    exit 0
else
    echo "ERROR"
    exit 1
fi
EOF

chmod +x /opt/firezone/health-check.sh

# Install simple HTTP server for health checks
apt-get install -y python3
cat > /etc/systemd/system/firezone-health.service <<EOF
[Unit]
Description=Firezone Health Check Server
After=network.target

[Service]
Type=simple
User=azureuser
WorkingDirectory=/opt/firezone
ExecStart=/usr/bin/python3 -m http.server 8080
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl enable firezone-health.service
systemctl start firezone-health.service

echo "Firezone Gateway setup completed successfully!"
echo "Gateway should be accessible on port 51820 (WireGuard)"
echo "Health check available on port 8080"
echo "Logs: /var/log/firezone-startup.log"