# Containerized Cloudflare Tunnel Setup

This guide explains how to run Cloudflare Tunnel as a containerized service.

## Architecture

```
Internet → Cloudflare Edge → Cloudflare Tunnel Pod → Traefik Ingress → Apps
```

The tunnel runs as a Kubernetes Deployment with:
- Configuration stored in a ConfigMap
- Credentials stored as a Sealed Secret
- Health checks via metrics endpoint
- Automatic restarts on failure

## Prerequisites

1. Existing Cloudflare Tunnel created and configured
2. Tunnel credentials JSON file
3. `kubeseal` CLI tool installed

## Setup Instructions

### Option 1: Automated Setup (Recommended)

1. Run the setup script:
   ```bash
   ./setup-cloudflare-tunnel.sh
   ```

2. Follow the prompts to enter:
   - Your tunnel ID
   - Your domain name
   - Path to your credentials file

3. The script will automatically:
   - Update configuration files with your values
   - Create the sealed secret
   - Prepare all manifests for deployment

### Option 2: Manual Setup

1. **Get your tunnel credentials**:
   - If you already have a tunnel, find the credentials at `/root/.cloudflared/{TUNNEL_ID}.json`
   - If creating a new tunnel:
     ```bash
     cloudflared tunnel create my-k8s-tunnel
     ```

2. **Update the configuration**:
   - Edit `flux/apps/cloudflare-tunnel/config.yaml`
   - Replace `YOUR_TUNNEL_ID` with your actual tunnel ID
   - Replace `yourdomain.com` with your actual domain

3. **Create the sealed secret**:
   ```bash
   kubectl create secret generic cloudflare-tunnel-credentials \
     --from-file=credentials.json=/path/to/your/credentials.json \
     --namespace=cloudflare-tunnel \
     --dry-run=client -o yaml | \
     kubeseal --controller-name=sealed-secrets \
     --controller-namespace=sealed-secrets \
     --format yaml > sealed-secret.yaml
   ```

4. **Update the sealed secret file**:
   - Replace the content in `flux/apps/cloudflare-tunnel/sealed-secret.yaml`

## Configuration Details

### ConfigMap (`config.yaml`)
- Contains the tunnel configuration
- Routes traffic to Traefik ingress controller
- Includes health check endpoint on port 2000

### Deployment (`deployment.yaml`)
- Uses official `cloudflare/cloudflared:latest` image
- Includes liveness probe for health checking
- Resource limits: 128Mi memory, 100m CPU
- Mounts config and credentials as volumes

### Service (`service.yaml`)
- Exposes metrics endpoint for monitoring
- Used by the liveness probe

### Sealed Secret (`sealed-secret.yaml`)
- Securely stores tunnel credentials
- Encrypted using your cluster's sealed-secrets controller

## Deployment

1. **Commit changes**: Flux will automatically apply the manifests

2. **Monitor deployment**:
   ```bash
   # Watch Flux sync
   flux get kustomizations
   
   # Check pod status
   kubectl get pods -n cloudflare-tunnel
   
   # View logs
   kubectl logs -n cloudflare-tunnel deployment/cloudflare-tunnel -f
   ```

## Verification

1. **Check tunnel status**:
   ```bash
   kubectl get pods -n cloudflare-tunnel
   kubectl logs -n cloudflare-tunnel deployment/cloudflare-tunnel
   ```

2. **Test connectivity**:
   - Visit domain in a browser
   - Traffic should route through the containerized tunnel

3. **Monitor metrics** (optional):
   ```bash
   kubectl port-forward -n cloudflare-tunnel svc/cloudflare-tunnel-metrics 2000:2000
   # Visit http://localhost:2000/metrics
   ```

## Troubleshooting

### Common Issues

1. **Pod CrashLoopBackOff**:
   - Check credentials are correctly mounted
   - Verify tunnel ID in config matches your tunnel
   - Check logs: `kubectl logs -n cloudflare-tunnel deployment/cloudflare-tunnel`

2. **DNS Resolution Issues**:
   - Ensure your domain is properly configured in Cloudflare
   - Verify tunnel routes are set up correctly

3. **Service Connectivity**:
   - Check that Traefik is accessible from the tunnel pod
   - Verify ingress configurations for your applications

### Useful Commands

```bash
# Check all resources
kubectl get all -n cloudflare-tunnel

# Describe deployment for events
kubectl describe deployment cloudflare-tunnel -n cloudflare-tunnel

# Check sealed secret status
kubectl get sealedsecrets -n cloudflare-tunnel

# Force restart deployment
kubectl rollout restart deployment/cloudflare-tunnel -n cloudflare-tunnel
```

## Migrating from Host Installation

If you're migrating from a host-based installation:

1. **Stop the host service**:
   ```bash
   sudo systemctl stop cloudflared
   sudo systemctl disable cloudflared
   ```

2. **Deploy the containerized version** using this guide

3. **Verify functionality** before removing host installation

4. **Clean up host installation** (optional):
   ```bash
   sudo rm /etc/cloudflared/config.yml
   sudo apt remove cloudflared  # or equivalent for your distro
   ```

## Security Considerations

- Credentials are encrypted using Sealed Secrets
- Container runs with minimal privileges
- Network policies can be added for additional isolation
- Regular image updates for security patches
