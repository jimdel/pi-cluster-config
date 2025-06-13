# Domain Configuration & Tunnel Routing Guide

How to register a domain and route traffic using Cloudflare & Namecheap (domain registrar).

Assumes: you own a domain named `example.com` with Namecheap.

## Step 1: Register Cloudflare Account
1. Go to [Cloudflare](https://www.cloudflare.com/).
2. Click on "Sign Up" and create an account.
3. Verify your email address.
4. Log in to your Cloudflare account.

# Step 2: Add Domain to Cloudflare
1. Click on "Add a Site".
2. Enter your domain name (e.g., `example.com`).
3. Click "Add Site".
4. Choose a plan (Free).
5. Click "Confirm Plan".
6. Cloudflare will scan your existing DNS records. Review them and click "Continue".
7. Cloudflare will provide you with nameservers.
8. Copy the nameservers provided by Cloudflare.

## Step 3: Update Nameservers in Namecheap
1. Log in to your Namecheap account.
2. Go to the "Domain List" section.
3. Find your domain (e.g., `example.com`) and click on "Manage".
4. Scroll down to the "Nameservers" section.
5. Select "Custom DNS" from the dropdown.
6. Paste the nameservers provided by Cloudflare into the fields.
7. Click the green checkmark to save changes.

## Step 4: Create Cloudflare Tunnel
1. `ssh` into your master node.
2. Install Cloudflare CLI if not already installed:
   ```bash
   wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb
sudo dpkg -i cloudflared-linux-arm64.deb

   ```
3. Authenticate Cloudflare CLI:
   ```bash
   sudo cloudflared tunnel login
   ```
4. Create a new tunnel:
   ```bash
   sudo cloudflared tunnel create my-tunnel
   ```
   - **Note:** save the tunnel ID.

5. Configure the tunnel to route traffic:
   ```bash
   sudo cloudflared tunnel route dns my-tunnel example.com
   ```
6. Create a configuration file for the tunnel:
   ```bash
   sudo nano /etc/cloudflared/config.yml
   ```
    Add the following content:
    ```yaml
    tunnel: my-tunnel
    credentials-file: /root/.cloudflared/{TUNNEL_ID}.json
    ingress:
      - hostname: example.com
        service: https://localhost:443 # assumes certificate is set up via cert-manager
        originRequest:
            noTLSVerify: true # necessary since we are using self-signed certificates
      - service: http_status:404
    ```
7. Start the tunnel:
   ```bash
   sudo cloudflared tunnel run my-tunnel
   ```
## Step 5: Test the Domain
1. Open a web browser.
2. Enter your domain name (e.g., `http://example.com`).
3. Verify that it resolves to the correct IP address and loads your web application.
4. If you see Traefik's 404 page, review your ports and configurations.

## Step 6: Set Tunnel to Start on Boot
1. Enable the tunnel to start on boot:
   ```bash
   sudo cloudflared service install
   ```
2. Enable the service to start on boot:
   ```bash
   sudo systemctl enable cloudflared
   ```
3. Start the service:
   ```bash
   sudo systemctl start cloudflared
   ```
4. Check the status of the service:
   ```bash
   sudo systemctl status cloudflared
   ```