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
sed -i.bak "s/YOUR_TUNNEL_ID/$TUNNEL_ID/g" flux/apps/cloudflare-tunnel/config.yaml
sed -i.bak "s/yourdomain.com/$DOMAIN/g" flux/apps/cloudflare-tunnel/config.yaml

# Create the sealed secret
echo "Creating sealed secret..."
kubectl create secret generic cloudflare-tunnel-credentials \
    --from-file=credentials.json="$CREDS_FILE" \
    --namespace=cloudflare-tunnel \
    --dry-run=client -o yaml | \
    kubeseal --controller-name=sealed-secrets \
    --controller-namespace=sealed-secrets \
    --format yaml > temp-sealed-secret.yaml

# Replace the placeholder in the sealed-secret.yaml
echo "Updating sealed secret file..."
# Extract the encrypted data from the temporary file
ENCRYPTED_DATA=$(grep -A 10 "encryptedData:" temp-sealed-secret.yaml | grep "credentials.json:" | awk '{print $2}')

# Update the sealed-secret.yaml file
sed -i.bak "s/ENCRYPTED_CREDENTIALS_PLACEHOLDER/$ENCRYPTED_DATA/g" flux/apps/cloudflare-tunnel/sealed-secret.yaml

# Clean up
rm temp-sealed-secret.yaml
rm flux/apps/cloudflare-tunnel/config.yaml.bak
rm flux/apps/cloudflare-tunnel/sealed-secret.yaml.bak

echo
echo "============================"
echo "SUCCESS: Setup complete!"
echo "============================"
