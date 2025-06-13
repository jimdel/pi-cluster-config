# Setup Flux

## Step 1: Install Flux CLI
1. Download and install the Flux CLI:
   ```bash
   curl -s https://fluxcd.io/install.sh | sudo bash
   ```
2. Verify the installation:
   ```bash  
    flux --version
    ```
## Step 2: Bootstrap Flux in Your Cluster
1. Execute the bootstrap command to set up Flux in your cluster:
   ```bash
    export GITHUB_USER=<your-github-username>
    export GITHUB_REPO=<your-config-repo-name>
    export GITHUB_TOKEN=<a GitHub personal access token with repo access>
    export CLUSTER_NAME=pi-cluster

    flux bootstrap github \
    --owner=$GITHUB_USER \
    --repository=$GITHUB_REPO \
    --branch=main \
    --path=clusters/$CLUSTER_NAME \
    --personal

   ```
   

   