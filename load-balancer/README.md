# MetalLB Load Balancer Configuration

## Overview

MetalLB is a load balancer implementation for bare metal Kubernetes clusters. It provides network load balancers to services of type LoadBalancer, which are typically unavailable in bare metal environments without an external load balancer provider.

## Configuration

The MetalLB configuration in this directory uses the Layer 2 mode to announce service IPs. The configuration file `metallb.config.yaml` defines the IP address pools that MetalLB can assign to LoadBalancer services.

## Installation

### Prerequisites

- A running Kubernetes cluster
- kubectl command-line tool configured to communicate with your cluster

### Steps

1. Install MetalLB components:

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
```

2. Wait for MetalLB pods to be ready:

```bash
kubectl wait --namespace metallb-system \
                --for=condition=ready pod \
                --selector=app=metallb \
                --timeout=90s
```

3. Apply the configuration:

```bash
kubectl apply -f metallb.config.yaml
```

## Usage

To use MetalLB, create a service with `type: LoadBalancer`. MetalLB will automatically assign an IP address from the configured pool.

Example:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: example-service
spec:
  selector:
    app: example
  ports:
  - port: 80
    targetPort: 8080
  type: LoadBalancer
```

## Troubleshooting

- Check MetalLB logs: `kubectl logs -n metallb-system -l app=metallb`
- Verify IP address pool configuration
- Ensure there are no IP conflicts in your network

## Additional Resources

- [MetalLB Official Documentation](https://metallb.universe.tf/)
- [Configuration Examples](https://metallb.universe.tf/configuration/)
- [MetalLB GitHub Repository](https://github.com/metallb/metallb)