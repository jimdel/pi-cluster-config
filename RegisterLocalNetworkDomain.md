# Registering a Local Domain on Your Network

A step by step guide on how to register a local domain on your network to test your web applications.

## Step 1: Access Router Settings
1. Open a web browser.
2. Enter your router's IP address in the address bar (commonly `192.168.1.1`)
3. Log in with your router's admin credentials.
4. Navigate to the DNS settings or Local Domain section.

## Step 2: Add Local Domain
1. Look for an option to add a new local domain or hostname.
2. Enter the desired local domain name (e.g., `myapp.local`).
3. Specify the IP address of the master node of the cluster
4. Save the changes.
5. Restart the router if necessary.

## Step 3: Test the Local Domain
1. Open a web browser.
2. Enter the local domain name you just registered (e.g., `http://myapp.local`).
3. Verify that it resolves to the correct IP address and loads your web application.
4. If you see Traefik's  404 page review ports & configurations.