#!/bin/bash
# Certificate Chain Generator — Azure Jenkins (Azure-only)
# Root CA → Intermediate CA → Azure Jenkins Leaf Cert
# Run ONCE locally, then push to Azure Key Vault via Terraform
#
# Usage:
#   bash generate-certs.sh
#
# Optional env overrides:
#   ROOT_CA_PASS=mypassword INTERMEDIATE_CA_PASS=mypassword PFX_PASS=mypassword bash generate-certs.sh

set -e

DOMAIN="learningmyway.space"
AZURE_JENKINS_DNS="jenkins-az.${DOMAIN}"
CERTS_DIR="$(cd "$(dirname "$0")" && pwd)"

# Passwords — override via env vars, defaults are for local dev only
ROOT_CA_PASS="${ROOT_CA_PASS:-rootca_dev_password}"
INTERMEDIATE_CA_PASS="${INTERMEDIATE_CA_PASS:-intermediateca_dev_password}"
PFX_PASS="${PFX_PASS:-pfx_dev_password}"

echo "================================================"
echo " Generating Certificate Chain — Azure Jenkins"
echo " Root CA → Intermediate CA → Leaf Cert"
echo "================================================"
echo " Domain:      ${DOMAIN}"
echo " Jenkins DNS: ${AZURE_JENKINS_DNS}"
echo ""

# Create directory structure
mkdir -p "${CERTS_DIR}/root-ca/newcerts"
mkdir -p "${CERTS_DIR}/intermediate-ca/newcerts"
mkdir -p "${CERTS_DIR}/leaf"

touch "${CERTS_DIR}/root-ca/index.txt"
touch "${CERTS_DIR}/intermediate-ca/index.txt"
echo "1000" > "${CERTS_DIR}/root-ca/serial"
echo "2000" > "${CERTS_DIR}/intermediate-ca/serial"

# ─── STEP 1: ROOT CA ──────────────────────────────────────────────────────────
echo "[1/4] Generating Root CA..."
openssl genrsa -aes256 \
  -passout "pass:${ROOT_CA_PASS}" \
  -out "${CERTS_DIR}/root-ca/root-ca.key.pem" 4096

openssl req -new -x509 \
  -key "${CERTS_DIR}/root-ca/root-ca.key.pem" \
  -passin "pass:${ROOT_CA_PASS}" \
  -out "${CERTS_DIR}/root-ca/root-ca.cert.pem" \
  -days 3650 \
  -config <(cat <<EOF
[ req ]
distinguished_name = req_distinguished_name
x509_extensions    = v3_ca
prompt             = no

[ req_distinguished_name ]
C  = US
ST = State
L  = City
O  = MyOrg
OU = IT
CN = MyOrg Root CA

[ v3_ca ]
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints       = critical, CA:true
keyUsage               = critical, digitalSignature, cRLSign, keyCertSign
EOF
)
echo "  ✅ Root CA: root-ca/root-ca.cert.pem"

# ─── STEP 2: INTERMEDIATE CA ──────────────────────────────────────────────────
echo "[2/4] Generating Intermediate CA..."
openssl genrsa -aes256 \
  -passout "pass:${INTERMEDIATE_CA_PASS}" \
  -out "${CERTS_DIR}/intermediate-ca/intermediate-ca.key.pem" 4096

openssl req -new \
  -key "${CERTS_DIR}/intermediate-ca/intermediate-ca.key.pem" \
  -passin "pass:${INTERMEDIATE_CA_PASS}" \
  -out "${CERTS_DIR}/intermediate-ca/intermediate-ca.csr.pem" \
  -subj "/C=US/ST=State/L=City/O=MyOrg/OU=IT/CN=MyOrg Intermediate CA"

openssl x509 -req \
  -in "${CERTS_DIR}/intermediate-ca/intermediate-ca.csr.pem" \
  -CA "${CERTS_DIR}/root-ca/root-ca.cert.pem" \
  -CAkey "${CERTS_DIR}/root-ca/root-ca.key.pem" \
  -passin "pass:${ROOT_CA_PASS}" \
  -CAcreateserial \
  -out "${CERTS_DIR}/intermediate-ca/intermediate-ca.cert.pem" \
  -days 1825 \
  -extensions v3_intermediate_ca \
  -extfile <(cat <<EOF
[ v3_intermediate_ca ]
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints       = critical, CA:true, pathlen:0
keyUsage               = critical, digitalSignature, cRLSign, keyCertSign
EOF
)
echo "  ✅ Intermediate CA: intermediate-ca/intermediate-ca.cert.pem"

# ─── STEP 3: AZURE JENKINS LEAF CERT ──────────────────────────────────────────
echo "[3/4] Generating Azure Jenkins leaf certificate..."
openssl genrsa \
  -out "${CERTS_DIR}/leaf/jenkins-az.key.pem" 2048

openssl req -new \
  -key "${CERTS_DIR}/leaf/jenkins-az.key.pem" \
  -out "${CERTS_DIR}/leaf/jenkins-az.csr.pem" \
  -subj "/C=US/ST=State/L=City/O=MyOrg/OU=IT/CN=${AZURE_JENKINS_DNS}"

openssl x509 -req \
  -in "${CERTS_DIR}/leaf/jenkins-az.csr.pem" \
  -CA "${CERTS_DIR}/intermediate-ca/intermediate-ca.cert.pem" \
  -CAkey "${CERTS_DIR}/intermediate-ca/intermediate-ca.key.pem" \
  -passin "pass:${INTERMEDIATE_CA_PASS}" \
  -CAcreateserial \
  -out "${CERTS_DIR}/leaf/jenkins-az.cert.pem" \
  -days 365 \
  -extensions v3_leaf \
  -extfile <(cat <<EOF
[ v3_leaf ]
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid,issuer
basicConstraints       = critical, CA:false
keyUsage               = critical, digitalSignature, keyEncipherment
extendedKeyUsage       = serverAuth
subjectAltName         = @alt_names_az

[ alt_names_az ]
DNS.1 = ${AZURE_JENKINS_DNS}
DNS.2 = jenkins-az
IP.1  = 192.168.0.4
EOF
)
echo "  ✅ Leaf cert: leaf/jenkins-az.cert.pem"

# ─── STEP 4: BUILD CHAINS AND PKCS12 ──────────────────────────────────────────
echo "[4/4] Building certificate chain and PKCS12..."

# Full chain: leaf + intermediate + root
cat "${CERTS_DIR}/leaf/jenkins-az.cert.pem" \
    "${CERTS_DIR}/intermediate-ca/intermediate-ca.cert.pem" \
    "${CERTS_DIR}/root-ca/root-ca.cert.pem" \
    > "${CERTS_DIR}/leaf/jenkins-az.chain.pem"

# CA bundle for trust verification
cat "${CERTS_DIR}/intermediate-ca/intermediate-ca.cert.pem" \
    "${CERTS_DIR}/root-ca/root-ca.cert.pem" \
    > "${CERTS_DIR}/ca-bundle.pem"

# PKCS12 for Azure Key Vault import
openssl pkcs12 -export \
  -in "${CERTS_DIR}/leaf/jenkins-az.chain.pem" \
  -inkey "${CERTS_DIR}/leaf/jenkins-az.key.pem" \
  -out "${CERTS_DIR}/leaf/jenkins-az.pfx" \
  -passout "pass:${PFX_PASS}" \
  -name "jenkins-az"

echo "  ✅ Chain: leaf/jenkins-az.chain.pem"
echo "  ✅ CA bundle: ca-bundle.pem"
echo "  ✅ PFX: leaf/jenkins-az.pfx"

echo ""
echo "================================================"
echo " Certificate Summary"
echo "================================================"
echo ""
echo "  Root CA cert:      certs/root-ca/root-ca.cert.pem"
echo "  Intermediate cert: certs/intermediate-ca/intermediate-ca.cert.pem"
echo "  Jenkins leaf cert: certs/leaf/jenkins-az.cert.pem"
echo "  Jenkins chain:     certs/leaf/jenkins-az.chain.pem"
echo "  CA bundle:         certs/ca-bundle.pem"
echo "  Jenkins PFX:       certs/leaf/jenkins-az.pfx"
echo ""
echo "NEXT STEPS:"
echo "  1. cd azure/certs-keyvault && terraform init && terraform apply"
echo "  2. SSH to Jenkins VM and run: bash /tmp/jenkins-https-setup.sh"
echo "  3. Install root CA on your laptop: bash certs/install-root-ca.sh"
echo ""
echo "⚠️  Keep root-ca/root-ca.key.pem secure — never commit it!"
echo "⚠️  PFX password: ${PFX_PASS}"
