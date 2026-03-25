#!/bin/bash
# Jenkins HTTPS Setup — Azure
# Pulls certs from Azure Key Vault using VM managed identity
# Run on the Jenkins VM after Key Vault Terraform apply
#
# Usage:
#   KV_NAME=jenkins-certs-kv-xxxxx bash jenkins-https-setup.sh

set -e

KV_NAME="${KV_NAME:-}"
JENKINS_HOME="${JENKINS_HOME:-/jenkins/jenkins_home}"
CERT_DIR="/etc/jenkins/certs"

if [ -z "$KV_NAME" ]; then
  echo "ERROR: KV_NAME environment variable is required"
  echo "Usage: KV_NAME=jenkins-certs-kv-xxxxx bash jenkins-https-setup.sh"
  exit 1
fi

echo "=== Jenkins HTTPS Setup ==="
echo "Key Vault: $KV_NAME"
echo ""

mkdir -p "$CERT_DIR"

# Get access token from VM managed identity
echo "Getting managed identity token..."
TOKEN=$(curl -sf \
  -H "Metadata:true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

if [ -z "$TOKEN" ]; then
  echo "ERROR: Failed to get managed identity token. Is the VM identity configured?"
  exit 1
fi

# Fetch a secret from Key Vault
fetch_secret() {
  local name=$1
  local outfile=$2
  echo "  Fetching $name..."
  curl -sf \
    -H "Authorization: Bearer $TOKEN" \
    "https://${KV_NAME}.vault.azure.net/secrets/${name}?api-version=7.3" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['value'])" > "$outfile"
  echo "  ✅ $name → $outfile"
}

fetch_secret "jenkins-az-chain" "$CERT_DIR/jenkins.chain.pem"
fetch_secret "jenkins-az-key"   "$CERT_DIR/jenkins.key.pem"
fetch_secret "root-ca-cert"     "$CERT_DIR/root-ca.pem"

chmod 600 "$CERT_DIR/jenkins.key.pem"
chmod 644 "$CERT_DIR/jenkins.chain.pem"
chmod 644 "$CERT_DIR/root-ca.pem"

# Convert PEM chain + key to PKCS12 keystore for Jenkins
echo ""
echo "Converting to PKCS12 keystore..."
openssl pkcs12 -export \
  -in    "$CERT_DIR/jenkins.chain.pem" \
  -inkey "$CERT_DIR/jenkins.key.pem" \
  -out   "$CERT_DIR/jenkins.p12" \
  -passout pass:changeit \
  -name jenkins

chmod 600 "$CERT_DIR/jenkins.p12"
echo "  ✅ Keystore: $CERT_DIR/jenkins.p12"

# Configure Jenkins HTTPS via systemd override
echo ""
echo "Configuring Jenkins HTTPS..."
mkdir -p /etc/systemd/system/jenkins.service.d

cat > /etc/systemd/system/jenkins.service.d/https.conf <<EOF
[Service]
Environment="JENKINS_HTTPS_PORT=8443"
Environment="JENKINS_HTTPS_KEYSTORE=${CERT_DIR}/jenkins.p12"
Environment="JENKINS_HTTPS_KEYSTORE_PASSWORD=changeit"
Environment="JENKINS_PORT=-1"
EOF

# Install Root CA in system trust store
echo "Installing Root CA in system trust store..."
cp "$CERT_DIR/root-ca.pem" /usr/local/share/ca-certificates/myorg-root-ca.crt
update-ca-certificates

systemctl daemon-reload
systemctl restart jenkins

# Wait for Jenkins to come back up
echo ""
echo "Waiting for Jenkins to restart on HTTPS..."
for i in $(seq 1 30); do
  STATUS=$(curl -sk -o /dev/null -w "%{http_code}" "https://localhost:8443" 2>/dev/null || true)
  if echo "$STATUS" | grep -qE "200|403"; then
    echo "  ✅ Jenkins HTTPS ready (HTTP $STATUS)"
    break
  fi
  echo "  Waiting... ($i/30)"
  sleep 5
done

echo ""
echo "=== HTTPS Setup Complete ==="
echo "  Jenkins URL: https://jenkins-az.learningmyway.space:8443"
echo "  Cert dir:    $CERT_DIR"
echo ""
echo "  Distribute root CA to VPN clients:"
echo "    certs/root-ca/root-ca.cert.pem"
