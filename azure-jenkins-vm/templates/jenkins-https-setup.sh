#!/bin/bash
# Jenkins HTTPS Setup — runs via Azure VM Extension after Key Vault is ready
set -e
exec > >(tee -a /var/log/jenkins-https-setup.log) 2>&1

echo "=== Jenkins HTTPS Setup via Key Vault ==="
echo "Timestamp: $(date)"

KV_NAME="${kv_name}"
CERT_DIR="${cert_dir}"

mkdir -p "$CERT_DIR"
apt-get install -y openssl 2>/dev/null

# Get managed identity token
TOKEN=$(curl -sf \
  -H "Metadata:true" \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

if [ -z "$TOKEN" ]; then
  echo "ERROR: Failed to get managed identity token"
  exit 1
fi

fetch_secret() {
  local name=$1 outfile=$2
  echo "  Fetching $name..."
  curl -sf \
    -H "Authorization: Bearer $TOKEN" \
    "https://$${KV_NAME}.vault.azure.net/secrets/$${name}?api-version=7.3" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['value'])" > "$outfile"
}

fetch_secret "jenkins-az-chain" "$CERT_DIR/jenkins.chain.pem"
fetch_secret "jenkins-az-key"   "$CERT_DIR/jenkins.key.pem"
fetch_secret "root-ca-cert"     "$CERT_DIR/root-ca.pem"

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

# Install Root CA in system trust store
cp "$CERT_DIR/root-ca.pem" /usr/local/share/ca-certificates/myorg-root-ca.crt
update-ca-certificates

# Configure Jenkins HTTPS via systemd override
mkdir -p /etc/systemd/system/jenkins.service.d
cat > /etc/systemd/system/jenkins.service.d/https.conf <<EOF
[Service]
Environment="JENKINS_HTTPS_PORT=8443"
Environment="JENKINS_HTTPS_KEYSTORE=$${CERT_DIR}/jenkins.p12"
Environment="JENKINS_HTTPS_KEYSTORE_PASSWORD=changeit"
Environment="JENKINS_PORT=-1"
EOF

systemctl daemon-reload
systemctl restart jenkins

echo "Jenkins HTTPS configured on port 8443"
echo "Timestamp: $(date)"
