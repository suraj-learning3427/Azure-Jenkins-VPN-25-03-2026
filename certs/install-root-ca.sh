#!/bin/bash
# Install Root CA on your local machine so browsers trust Jenkins HTTPS
# Run this on your laptop (not the Jenkins VM)
#
# Usage:
#   bash certs/install-root-ca.sh

CERTS_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_CA="${CERTS_DIR}/root-ca/root-ca.cert.pem"

if [ ! -f "$ROOT_CA" ]; then
  echo "ERROR: Root CA not found at $ROOT_CA"
  echo "Run: bash certs/generate-certs.sh first"
  exit 1
fi

echo "=== Installing Root CA on local machine ==="
echo "  CA: $ROOT_CA"
echo ""

OS="$(uname -s)"

case "$OS" in
  Linux)
    echo "Detected: Linux"
    sudo cp "$ROOT_CA" /usr/local/share/ca-certificates/myorg-root-ca.crt
    sudo update-ca-certificates
    echo "  ✅ Root CA installed (system trust store)"
    echo "  ✅ Restart your browser to pick up the change"
    ;;

  Darwin)
    echo "Detected: macOS"
    sudo security add-trusted-cert \
      -d -r trustRoot \
      -k /Library/Keychains/System.keychain \
      "$ROOT_CA"
    echo "  ✅ Root CA installed (macOS Keychain)"
    echo "  ✅ Restart your browser to pick up the change"
    ;;

  MINGW*|CYGWIN*|MSYS*)
    echo "Detected: Windows (Git Bash)"
    echo "  Run this in PowerShell as Administrator:"
    echo ""
    echo "  Import-Certificate -FilePath '${ROOT_CA}' -CertStoreLocation Cert:\\LocalMachine\\Root"
    echo ""
    echo "  Or double-click the file and install to 'Trusted Root Certification Authorities'"
    ;;

  *)
    echo "Unknown OS: $OS"
    echo "Manually install: $ROOT_CA"
    echo "  - Windows: Import to 'Trusted Root Certification Authorities'"
    echo "  - macOS:   Keychain Access → System → Certificates → Import"
    echo "  - Linux:   copy to /usr/local/share/ca-certificates/ and run update-ca-certificates"
    ;;
esac

echo ""
echo "After installing, Jenkins HTTPS will be trusted at:"
echo "  https://jenkins-az.learningmyway.space:8443"
