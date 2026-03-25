#!/bin/bash
# Jenkins Installation Script for Azure VM (Ubuntu 22.04)
# Uses direct .deb download to avoid GPG key verification issues
exec > >(tee -a /var/log/jenkins-startup.log)
exec 2>&1

echo "Starting Jenkins VM setup..."
echo "Timestamp: $(date)"

DISK_DEVICE="${data_disk_device}"
MOUNT_POINT="${mount_point}"
JENKINS_PORT="${jenkins_port}"
KV_NAME="${kv_name}"
JENKINS_VERSION="2.479.3"

# Wait for data disk
echo "Waiting for data disk at $DISK_DEVICE..."
for i in $(seq 1 30); do
    if [ -e "$DISK_DEVICE" ]; then
        echo "Data disk found"
        break
    fi
    sleep 2
done

if [ ! -e "$DISK_DEVICE" ]; then
    echo "WARNING: Data disk not found at $DISK_DEVICE, trying /dev/sdc"
    DISK_DEVICE="/dev/sdc"
fi

# Format and mount data disk
if ! blkid "$DISK_DEVICE" 2>/dev/null; then
    echo "Formatting data disk..."
    mkfs.ext4 -F "$DISK_DEVICE"
fi

mkdir -p "$MOUNT_POINT"
mount "$DISK_DEVICE" "$MOUNT_POINT"

UUID=$(blkid -s UUID -o value "$DISK_DEVICE")
grep -q "$UUID" /etc/fstab || echo "UUID=$UUID $MOUNT_POINT ext4 defaults,nofail 0 2" >> /etc/fstab
echo "Data disk mounted at $MOUNT_POINT"

# Install Java
echo "Installing Java..."
apt-get update -y
apt-get install -y wget curl fontconfig openjdk-17-jre

# Install Jenkins via direct .deb download (avoids GPG repo issues)
echo "Downloading Jenkins $JENKINS_VERSION .deb package..."
wget -q -O /tmp/jenkins.deb "https://get.jenkins.io/debian-stable/jenkins_$${JENKINS_VERSION}_all.deb"

if [ $? -ne 0 ]; then
    echo "Primary download failed, trying mirror..."
    wget -q -O /tmp/jenkins.deb "https://mirrors.jenkins.io/debian-stable/jenkins_$${JENKINS_VERSION}_all.deb"
fi

echo "Installing Jenkins from .deb..."
apt-get install -y /tmp/jenkins.deb
rm -f /tmp/jenkins.deb

# Configure Jenkins home on data disk
systemctl stop jenkins || true
mkdir -p "$MOUNT_POINT/jenkins_home"
chown -R jenkins:jenkins "$MOUNT_POINT/jenkins_home"

mkdir -p /etc/systemd/system/jenkins.service.d
cat > /etc/systemd/system/jenkins.service.d/override.conf <<EOF
[Service]
Environment="JENKINS_HOME=$MOUNT_POINT/jenkins_home"
Environment="JENKINS_PORT=$JENKINS_PORT"
EOF

systemctl daemon-reload
systemctl enable jenkins
systemctl start jenkins

# Wait for Jenkins to be ready
echo "Waiting for Jenkins to start..."
for i in $(seq 1 60); do
    STATUS=$(curl -s -o /dev/null -w "%%{http_code}" "http://localhost:$JENKINS_PORT" 2>/dev/null)
    if echo "$STATUS" | grep -qE "200|403"; then
        echo "Jenkins is ready (HTTP $STATUS)"
        break
    fi
    echo "Waiting... ($i/60) - HTTP $STATUS"
    sleep 5
done

ADMIN_PASS_FILE="$MOUNT_POINT/jenkins_home/secrets/initialAdminPassword"
if [ -f "$ADMIN_PASS_FILE" ]; then
    echo "=== INITIAL ADMIN PASSWORD ==="
    cat "$ADMIN_PASS_FILE"
    echo "=============================="
fi

echo "Jenkins setup complete!"
echo "URL: http://localhost:$JENKINS_PORT"
echo "Timestamp: $(date)"

# ─── HTTPS SETUP VIA KEY VAULT ────────────────────────────────────────────────
if [ -n "$KV_NAME" ]; then
  echo "=== Setting up Jenkins HTTPS via Key Vault: $KV_NAME ==="
  CERT_DIR="/etc/jenkins/certs"
  mkdir -p "$CERT_DIR"

  # Wait for managed identity token (retry up to 10 min)
  echo "Waiting for managed identity token..."
  TOKEN=""
  for i in $(seq 1 60); do
    TOKEN=$(curl -sf \
      -H "Metadata:true" \
      "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net" \
      2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null || true)
    if [ -n "$TOKEN" ]; then
      echo "  Got managed identity token"
      break
    fi
    echo "  Waiting for token... ($i/60)"
    sleep 10
  done

  if [ -z "$TOKEN" ]; then
    echo "WARNING: Could not get managed identity token — skipping HTTPS setup"
  else
    # Fetch secret from Key Vault with retry
    fetch_kv_secret() {
      local secret_name=$1
      local outfile=$2
      for attempt in $(seq 1 20); do
        RESULT=$(curl -sf \
          -H "Authorization: Bearer $TOKEN" \
          "https://$${KV_NAME}.vault.azure.net/secrets/$${secret_name}?api-version=7.3" \
          2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['value'])" 2>/dev/null || true)
        if [ -n "$RESULT" ]; then
          echo "$RESULT" > "$outfile"
          echo "  ✅ Fetched: $secret_name"
          return 0
        fi
        echo "  Waiting for $secret_name in Key Vault... ($attempt/20)"
        sleep 30
      done
      echo "  WARNING: Could not fetch $secret_name after retries"
      return 1
    }

    fetch_kv_secret "jenkins-az-chain" "$CERT_DIR/jenkins.chain.pem" && \
    fetch_kv_secret "jenkins-az-key"   "$CERT_DIR/jenkins.key.pem"  && \
    fetch_kv_secret "root-ca-cert"     "$CERT_DIR/root-ca.pem"      && {
      chmod 600 "$CERT_DIR/jenkins.key.pem"
      chmod 644 "$CERT_DIR/jenkins.chain.pem" "$CERT_DIR/root-ca.pem"

      # Build PKCS12 keystore
      openssl pkcs12 -export \
        -in    "$CERT_DIR/jenkins.chain.pem" \
        -inkey "$CERT_DIR/jenkins.key.pem" \
        -out   "$CERT_DIR/jenkins.p12" \
        -passout pass:changeit \
        -name jenkins
      chmod 600 "$CERT_DIR/jenkins.p12"

      # Install Root CA
      cp "$CERT_DIR/root-ca.pem" /usr/local/share/ca-certificates/myorg-root-ca.crt
      update-ca-certificates

      # Configure Jenkins HTTPS
      mkdir -p /etc/systemd/system/jenkins.service.d
      cat > /etc/systemd/system/jenkins.service.d/https.conf <<EOF
[Service]
Environment="JENKINS_HTTPS_PORT=8443"
Environment="JENKINS_HTTPS_KEYSTORE=$CERT_DIR/jenkins.p12"
Environment="JENKINS_HTTPS_KEYSTORE_PASSWORD=changeit"
Environment="JENKINS_PORT=-1"
EOF
      systemctl daemon-reload
      systemctl restart jenkins
      echo "✅ Jenkins HTTPS configured on port 8443"
      echo "URL: https://jenkins-az.learningmyway.space:8443"
    }
  fi
fi
