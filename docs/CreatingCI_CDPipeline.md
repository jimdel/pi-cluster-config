# Creating a CI/CD Pipeline
This document provides a step-by-step guide to creating a Continuous Integration/Continuous Deployment (CI/CD) pipeline using Flux, GitHub Actions, and Docker. This pipeline will automate the process of building, testing, and deploying the application. It will build a Docker image, push it to the Docker container registry, and update the deployment configuration in a Git repository.

## Step 1: Configure Flux for Deployment
- Create a `{{APP_NAME}}-release.yaml` file in `/utils/flux/releases/` with the following content:
  ```yaml
    apiVersion: helm.toolkit.fluxcd.io/v2beta1
    kind: HelmRelease
    metadata:
    name: {{APP_NAME}}
    namespace: flux-system
    spec:
    interval: 5m
    chart:
        spec:
        chart: ./apps/{{APPNAME}}  # Path to your existing Helm chart
        version: '*'
        sourceRef:
            kind: GitRepository
            name: {{APP_NAME}}-source
            namespace: flux-system
        interval: 1m
    targetNamespace: {{APP_NAME}}
    install:
        createNamespace: true
    upgrade:
        remediation:
        retries: 3
    values:
        # Override any values from your existing values.yaml here
        image:
        tag: "latest"  # This will be updated by GitHub Actions
        # Add any other value overrides specific to your environment
    ```
- Create a `{{APP_NAME}}-source.yaml` file in `/utils/flux/sources/` with the following content:
  ```yaml
    apiVersion: source.toolkit.fluxcd.io/v1beta1
    kind: GitRepository
    metadata:
    name: {{APP_NAME}}-source
    namespace: flux-system
    spec:
    interval: 1m
    ref:
        branch: main # Change to your default branch if different
    url: {{GIT_REPO_URL}}
    ```
- Register the new resources in the `kustomization.yaml` file located in `/utils/flux/kustomization/`:
  ```yaml
    resources:
        #Add these two lines
      - ../sources/{{APP_NAME}}-source.yaml
      - ../releases/{{APP_NAME}}-release.yaml
  ```

## Step 2: Set Up GitHub Actions Workflows

### Create the CI/CD Workflow in this repository
- Create a new GitHub Actions workflow file at `.github/workflows/{{APP_NAME}}-ci-cd.yaml` with the following content:
  ```yaml
    name: <APP_NAME> CI/CD # Replace <APP_NAME> with your actual app name
    on:
      repository_dispatch:
        types: [<APP_NAME>-build] # Replace <APP_NAME> with your actual app name
      workflow_dispatch:
        inputs:
          image_tag:
            description: 'Docker image tag to deploy'
            required: true
            default: 'latest'
          registry:
            description: 'Docker registry'
            required: true
            default: 'docker.io'

    env:
      REGISTRY: docker.io
      IMAGE_NAME: ${{ secrets.DOCKERHUB_USERNAME }}/<APP_NAME> # Replace <APP_NAME> with your actual app name

    jobs:
      deploy:
        runs-on: ubuntu-latest
        permissions:
          contents: write

        steps:
        - name: Extract deployment info
          id: deploy-info
          run: |
            if [ "${{ github.event_name }}" = "repository_dispatch" ]; then
              echo "image_tag=${{ github.event.client_payload.image_tag || 'latest' }}" >> $GITHUB_OUTPUT
              echo "registry=${{ github.event.client_payload.registry || 'docker.io' }}" >> $GITHUB_OUTPUT
              echo "webapp_sha=${{ github.event.client_payload.sha }}" >> $GITHUB_OUTPUT
            else
              echo "image_tag=${{ github.event.inputs.image_tag }}" >> $GITHUB_OUTPUT
              echo "registry=${{ github.event.inputs.registry }}" >> $GITHUB_OUTPUT
              echo "webapp_sha=manual-deploy" >> $GITHUB_OUTPUT
            fi

        - name: Checkout config repository
          uses: actions/checkout@v4
          with:
            token: ${{ secrets.GITHUB_TOKEN }}

        - name: Install yq
          run: |
            sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
            sudo chmod +x /usr/local/bin/yq

        - name: Update Helm values
          run: |
            IMAGE_TAG="${{ steps.deploy-info.outputs.image_tag }}"
            REGISTRY="${{ steps.deploy-info.outputs.registry }}"
            IMAGE_REPO="${REGISTRY}/${{ env.IMAGE_NAME }}"
            
            echo "Updating image to: ${IMAGE_REPO}:${IMAGE_TAG}"
            
            # Update both image repository and tag in HelmRelease
            yq eval '.spec.values.image.repository = "'${IMAGE_REPO}'"' -i utils/flux/releases/jimdel-release.yaml
            yq eval '.spec.values.image.tag = "'${IMAGE_TAG}'"' -i utils/flux/releases/jimdel-release.yaml

        - name: Verify changes
          run: |
            echo "Updated HelmRelease:"
            yq eval '.spec.values.image' utils/flux/releases/jimdel-release.yaml

        - name: Commit and push changes
          run: |
            git config --local user.email "github-actions[bot]@users.noreply.github.com"
            git config --local user.name "github-actions[bot]"
            git add utils/flux/releases/jimdel-release.yaml
            if git diff --staged --quiet; then
              echo "No changes to commit"
            else
              git commit -m "🚀 Deploy jimdel:${{ steps.deploy-info.outputs.image_tag }} (webapp: ${{ steps.deploy-info.outputs.webapp_sha }})"
              git push
            fi

        - name: Summary
          run: |
            echo "## Deployment Summary" >> $GITHUB_STEP_SUMMARY
            echo "- **Image**: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ steps.deploy-info.outputs.image_tag }}" >> $GITHUB_STEP_SUMMARY
            echo "- **Registry**: ${{ steps.deploy-info.outputs.registry }}" >> $GITHUB_STEP_SUMMARY
            echo "- **Webapp SHA**: ${{ steps.deploy-info.outputs.webapp_sha }}" >> $GITHUB_STEP_SUMMARY
            echo "- **Config Updated**: $(date)" >> $GITHUB_STEP_SUMMARY
        ```
      - Replace `<APP_NAME>` with your actual application name and adjust paths as necessary.
      - Add the following secrets to the GitHub repository Settings > Secrets and variables > Actions:
        - `DOCKERHUB_USERNAME`: Your Docker Hub username.
        - `DOCKERHUB_TOKEN`: A Docker Hub access token or password.
### Create the CI/CD Trigger Workflow in the Application Repository
- In the application repository, create a new GitHub Actions workflow file at `.github/workflows/deploy.yaml` with the following content:
  ```yaml
    name: Deploy to Pi Cluster
    on:
      push:
        branches: [ main ]
      workflow_dispatch:

    env:
      REGISTRY: docker.io
      IMAGE_NAME: ${{ secrets.DOCKERHUB_USERNAME }}/<APP_NAME>  # Replace <APP_NAME> with your actual app name

    jobs:
      build-and-push:
        runs-on: ubuntu-latest
        outputs:
          image-tag: ${{ steps.meta.outputs.tags }}
          image-digest: ${{ steps.build.outputs.digest }}
        
        steps:
        - name: Checkout webapp repository
          uses: actions/checkout@v4

        - name: Set up Docker Buildx
          uses: docker/setup-buildx-action@v3

        - name: Log in to Docker Hub
          uses: docker/login-action@v3
          with:
            registry: ${{ env.REGISTRY }}
            username: ${{ secrets.DOCKERHUB_USERNAME }}
            password: ${{ secrets.DOCKERHUB_TOKEN }}

        - name: Extract metadata
          id: meta
          uses: docker/metadata-action@v5
          with:
            images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
            tags: |
              type=raw,value=main-${{ github.sha }}
              type=raw,value=latest
              type=ref,event=branch
              type=sha,prefix={{branch}}-
        - name: Build and push Docker image
          id: build
          uses: docker/build-push-action@v5
          with:
            context: .
            platforms: linux/amd64,linux/arm64  # Multi-platform build for Pi compatibility
            push: true
            tags: ${{ steps.meta.outputs.tags }}
            labels: ${{ steps.meta.outputs.labels }}
            cache-from: type=gha
            cache-to: type=gha,mode=max

      trigger-deploy:
        needs: build-and-push
        runs-on: ubuntu-latest
        steps:
        - name: Trigger deployment in config repo
          run: |
            curl -X POST \
              -H "Authorization: Bearer ${{ secrets.CONFIG_REPO_TRIGGER_TOKEN }}" \
              -H "Accept: application/vnd.github.v3+json" \
              -H "X-GitHub-Api-Version: 2022-11-28" \
              https://api.github.com/repos/${{ github.repository_owner }}/pi-cluster-config/dispatches \
              -d '{
                "event_type": "<APP_NAME>-build", # Replace <APP_NAME> with your actual app name
                "client_payload": {
                  "ref": "${{ github.ref_name }}",
                  "sha": "${{ github.sha }}",
                  "repository": "${{ github.repository }}",
                  "image_tag": "main-${{ github.sha }}",
                  "registry": "docker.io"
                }
              }'
  ```
  - Replace `<APP_NAME>` with your actual application name and adjust paths as necessary.
  - Add the following secret to the GitHub repository Settings > Secrets and variables > Actions:
    - `CONFIG_REPO_TRIGGER_TOKEN`: A GitHub Personal Access Token (PAT) with `repo` scope for the configuration repository. 
      - See: [How to create a PAT](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token).
    - `DOCKERHUB_USERNAME`: Your Docker Hub username.