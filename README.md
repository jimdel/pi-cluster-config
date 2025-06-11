# Pi Cluster Config

This repository contains the configuration files for a k3s cluster running on Raspberry Pis.

## Load Balancer Configuration

K3s clusters come bundled with ServiceLB but this is not suitable for production use. Instead, I decided to use MetalLB to provide a more robust load balancing solution.

### Comparison: ServiceLB vs MetalLB
| Feature                  | **ServiceLB (K3s default)** | **MetalLB**                           |
| ------------------------ | --------------------------- | ------------------------------------- |
| **Bundled with K3s**     | ✅ Yes                       | ❌ No       |
| **Works out-of-the-box** | ✅ Yes (basic)               | ❌ Requires configuration              |
| **Supports IP Pools**    | ❌ No (1 IP per node)        | ✅ Yes (flexible IP ranges)            |
| **Shared IPs (L2 mode)** | ❌ No                        | ✅ Yes (one IP can float across nodes) |
| **HA Load Balancing**    | ⚠️ Limited (1 IP → 1 Node)  | ✅ True Load Balancer behavior         |
| **Production Ready**     | ⚠️ Basic use/dev only       | ✅ Widely used in production           |

## To Do:
- [ ] Add more documentation
- [ ] Combine with Anisble repo for Pi setup