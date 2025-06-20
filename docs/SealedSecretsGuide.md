# Sealed Secrets Usage Guide

This guide explains how to use Sealed Secrets in your Kubernetes cluster.

## What is Sealed Secrets?

Sealed Secrets is a Kubernetes controller and tool that allows you to encrypt your Kubernetes Secrets so they can be stored safely in a Git repository. The controller running in your cluster is the only one with access to the private key needed to decrypt the secrets.

## Installation

Sealed Secrets is installed in the cluster via Flux using a HelmRelease. The configuration is in `flux/apps/sealed-secrets/`.

## Using Sealed Secrets

### Installing the kubeseal CLI

You need to install the `kubeseal` CLI tool on your local machine to encrypt secrets:

```bash
# macOS with Homebrew
brew install kubeseal

```

### Creating Sealed Secrets

1. First, create a regular Kubernetes secret:

```bash
kubectl create secret generic my-secret --from-literal=key1=value1 --from-literal=key2=value2 --dry-run=client -o yaml > my-secret.yaml
```

2. Use kubeseal to encrypt it:

```bash
kubeseal --controller-name=sealed-secrets --controller-namespace=sealed-secrets --format yaml < my-secret.yaml > sealed-secret.yaml
```

3. Apply the sealed secret to your cluster:

```bash
kubectl apply -f sealed-secret.yaml
```

4. The controller will decrypt the sealed secret and create a regular secret in the cluster.

### Getting the Public Key

You can fetch the public key to encrypt secrets offline:

```bash
kubeseal --controller-name=sealed-secrets --controller-namespace=sealed-secrets --fetch-cert > public-key-cert.pem
```

Then use it to seal secrets without having direct access to the cluster:

```bash
kubeseal --cert=public-key-cert.pem --format yaml < my-secret.yaml > sealed-secret.yaml
```

## Backing Up the Sealed Secrets Key

The private key used by the controller is stored in a secret named `sealed-secrets-key` in the `sealed-secrets` namespace. It's important to back up this key in case you need to restore the controller.

```bash
kubectl get secret -n sealed-secrets sealed-secrets-key -o yaml > sealed-secrets-key.yaml
```

Store this backup securely, as it contains the private key that can decrypt all your sealed secrets.

## References

- [Sealed Secrets GitHub Repository](https://github.com/bitnami-labs/sealed-secrets)
- [Sealed Secrets Documentation](https://github.com/bitnami-labs/sealed-secrets#sealed-secrets-for-kubernetes)
