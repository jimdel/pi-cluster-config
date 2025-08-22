#!/bin/bash

# Cloudflare Tunnel Setup Script
# This script helps you create the sealed secret for your Cloudflare Tunnel credentials

set -e

echo " >>> Cloudflare Tunnel Containerization Setup <<<"
echo "=============================================="
echo

# Check if kubeseal is installed
if ! command -v kubeseal &> /dev/null; then
    echo "❌ kubeseal is not installed. Please install it first:"
    echo "   brew install kubeseal"
    exit 1
fi

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ kubectl is not configured or cluster is not accessible"
    exit 1
fi


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

echo
echo "   Configuration Summary:"
echo "   Tunnel ID: $TUNNEL_ID"
echo "   Domain: $DOMAIN"
echo "   Credentials: $CREDS_FILE"
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
# Use different delimiter and escape special characters
sed -i.bak "s|YOUR_TUNNEL_ID|$TUNNEL_ID|g" flux/apps/cloudflare-tunnel/config.yaml
sed -i.bak "s|yourdomain.com|$DOMAIN|g" flux/apps/cloudflare-tunnel/config.yaml

# Create the sealed secret
echo "Creating sealed secret..."
if ! kubectl create secret generic cloudflare-tunnel-credentials \
    --from-file=credentials.json="$CREDS_FILE" \
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
ENCRYPTED_DATA=$(grep -A 10 "encryptedData:" temp-sealed-secret.yaml | grep "credentials.json:" | awk '{print $2}')

if [ -z "$ENCRYPTED_DATA" ]; then
    echo "ERROR: Failed to extract encrypted data from sealed secret"
    rm -f temp-sealed-secret.yaml
    exit 1
fi

# Update the sealed-secret.yaml file using pipe delimiter to avoid conflicts
sed -i.bak "s|ENCRYPTED_CREDENTIALS_PLACEHOLDER|$ENCRYPTED_DATA|g" flux/apps/cloudflare-tunnel/sealed-secret.yaml

# Clean up
rm -f temp-sealed-secret.yaml
rm -f flux/apps/cloudflare-tunnel/config.yaml.bak
rm -f flux/apps/cloudflare-tunnel/sealed-secret.yaml.bak

echo
echo "============================"
echo "SUCCESS: Setup complete!"
echo "============================"
echo
echo "📋 Next steps:"
echo "1. Review the generated files in flux/apps/cloudflare-tunnel/"
echo "2. Commit and push the changes to your Git repository:"
echo "   git add flux/apps/cloudflare-tunnel/"
echo "   git commit -m 'Add containerized Cloudflare Tunnel'"
echo "   git push"
echo "3. Monitor the deployment:"
echo "   kubectl get pods -n cloudflare-tunnel"
echo "   kubectl logs -n cloudflare-tunnel deployment/cloudflare-tunnel -f"
echo
echo "🎯 Your Cloudflare Tunnel is now containerized and ready for deployment!"
