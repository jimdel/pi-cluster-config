#!/bin/bash

# Cloudflare Tunnel Setup Script
# This script helps you create the sealed secret for your Cloudflare Tunnel credentials

set -e

echo " >>> Cloudflare Tunnel Containerization Setup <<<"
echo "=============================================="
echo

# Check if kubeseal is installed
if ! command -v kubeseal &> /dev/null; then
    echo "ERROR: kubeseal is not installed"
    exit 1
fi

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo "ERROR: kubectl is not configured or cluster is not accessible"
    exit 1
fi

# Check if cloudflared is installed
if ! command -v cloudflared &> /dev/null; then
    echo "ERROR: cloudflared is not installed"
    exit 1
fi

echo "Checking for origin certificate..."
CERT_FILE=""

# Check common locations for cert.pem
CERT_LOCATIONS=(
    "$HOME/.cloudflared/cert.pem"
    "/etc/cloudflared/cert.pem"
    "/usr/local/etc/cloudflared/cert.pem"
)

for location in "${CERT_LOCATIONS[@]}"; do
    if [ -f "$location" ]; then
        CERT_FILE="$location"
        echo "SUCCESS: Found origin certificate at: $CERT_FILE"
        break
    fi
done

# If no certificate found, help user create one
if [ -z "$CERT_FILE" ]; then
    echo "WARNING: Origin certificate not found in common locations."
    echo "   This certificate is required for the tunnel to authenticate with Cloudflare."
    echo
    read -p "Would you like to generate the origin certificate now? (y/N): " GENERATE_CERT
    
    if [ "$GENERATE_CERT" = "y" ] || [ "$GENERATE_CERT" = "Y" ]; then
        echo "Generating origin certificate..."
        echo "   This will open your browser to authenticate with Cloudflare."
        echo "   Please log in and authorize the certificate generation."
        echo
        
        if cloudflared tunnel login; then
            CERT_FILE="$HOME/.cloudflared/cert.pem"
            if [ -f "$CERT_FILE" ]; then
                echo "SUCCESS: Origin certificate created successfully at: $CERT_FILE"
            else
                echo "ERROR: Certificate generation failed or file not found at expected location"
                exit 1
            fi
        else
            echo "ERROR: Failed to generate origin certificate"
            exit 1
        fi
    else
        echo "ERROR: Origin certificate is required. Please run 'cloudflared tunnel login' first."
        exit 1
    fi
fi

echo

# Get tunnel information
read -p "Enter your Cloudflare Tunnel ID: " TUNNEL_ID
read -p "Enter your domain (e.g., example.com): " DOMAIN
read -p "Enter the path to your tunnel credentials JSON file: " CREDS_FILE

# Validate inputs
if [ -z "$TUNNEL_ID" ] || [ -z "$DOMAIN" ] || [ -z "$CREDS_FILE" ]; then
    echo "ERROR: All fields are required"
    exit 1
fi

# Validate tunnel ID format (should be a UUID)
if ! [[ "$TUNNEL_ID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
    echo "WARNING: Tunnel ID doesn't appear to be a valid UUID format"
    read -p "Continue anyway? (y/N): " CONTINUE
    if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
        exit 1
    fi
fi

if [ ! -f "$CREDS_FILE" ]; then
    echo "ERROR: Credentials file not found: $CREDS_FILE"
    exit 1
fi

if [ ! -f "$CERT_FILE" ]; then
    echo "ERROR: Origin certificate file not found: $CERT_FILE"
    exit 1
fi

echo
echo "Configuration Summary:"
echo "   Tunnel ID: $TUNNEL_ID"
echo "   Domain: $DOMAIN"
echo "   Credentials: $CREDS_FILE"
echo "   Origin Certificate: $CERT_FILE"
echo

read -p "Do you want to proceed? (y/N): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "TERMINATE: Setup cancelled"
    exit 1
fi

echo
echo "Setting up Cloudflare Tunnel..."

# Update the config.yaml with actual values
echo "Updating configuration..."
sed -i.bak "s|YOUR_TUNNEL_ID|$TUNNEL_ID|g" flux/apps/cloudflare-tunnel/config.yaml
sed -i.bak "s|yourdomain.com|$DOMAIN|g" flux/apps/cloudflare-tunnel/config.yaml

# Create the sealed secret with both credentials and certificate
echo "Creating sealed secret with credentials and origin certificate..."
if ! kubectl create secret generic cloudflare-tunnel-credentials \
    --from-file=credentials.json="$CREDS_FILE" \
    --from-file=cert.pem="$CERT_FILE" \
    --namespace=cloudflare-tunnel \
    --dry-run=client -o yaml | \
    kubeseal --controller-name=sealed-secrets \
    --controller-namespace=sealed-secrets \
    --format yaml > temp-sealed-secret.yaml; then
    echo "ERROR: Failed to create sealed secret"
    exit 1
fi

# Replace the placeholder in the sealed-secret.yaml
echo "Updating sealed secret file..."

# Extract the encrypted data from the temporary file
ENCRYPTED_CREDENTIALS=$(grep -A 20 "encryptedData:" temp-sealed-secret.yaml | grep "credentials.json:" | awk '{print $2}')
ENCRYPTED_CERT=$(grep -A 20 "encryptedData:" temp-sealed-secret.yaml | grep "cert.pem:" | awk '{print $2}')

if [ -z "$ENCRYPTED_CREDENTIALS" ] || [ -z "$ENCRYPTED_CERT" ]; then
    echo "ERROR: Failed to extract encrypted data from sealed secret"
    echo "   Credentials data: ${ENCRYPTED_CREDENTIALS:0:20}..."
    echo "   Certificate data: ${ENCRYPTED_CERT:0:20}..."
    rm -f temp-sealed-secret.yaml
    exit 1
fi

# Create the complete sealed secret content
cat > flux/apps/cloudflare-tunnel/sealed-secret.yaml << EOF
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: cloudflare-tunnel-credentials
  namespace: cloudflare-tunnel
spec:
  encryptedData:
    credentials.json: $ENCRYPTED_CREDENTIALS
    cert.pem: $ENCRYPTED_CERT
  template:
    metadata:
      name: cloudflare-tunnel-credentials
      namespace: cloudflare-tunnel
    type: Opaque
EOF

# Clean up
rm -f temp-sealed-secret.yaml
rm -f flux/apps/cloudflare-tunnel/config.yaml.bak
rm -f flux/apps/cloudflare-tunnel/sealed-secret.yaml.bak

echo
echo "============================"
echo "SUCCESS: Setup complete!"
echo "============================"
echo
echo "Next steps:"
echo "1. Review the generated files in flux/apps/cloudflare-tunnel/"
echo "2. Commit and push the changes to your Git repository:"
echo "   git add flux/apps/cloudflare-tunnel/"
echo "   git commit -m 'Add containerized Cloudflare Tunnel with origin certificate'"
echo "   git push"
echo "3. Monitor the deployment:"
echo "   kubectl get pods -n cloudflare-tunnel"
echo "   kubectl logs -n cloudflare-tunnel deployment/cloudflare-tunnel -f"
echo
echo "If you encounter origin certificate errors, verify that:"
echo "   - The certificate file is correctly mounted in the container"
echo "   - The tunnel has proper permissions in your Cloudflare account"
echo "   - Your domain is properly configured in Cloudflare DNS"
echo
echo "Your Cloudflare Tunnel is now containerized and ready for deployment!"