# Registry Configuration Fix

## Problem
Kubernetes worker nodes cannot pull images from the Forgejo registry because:
1. Registry runs on HTTP but K8s expects HTTPS
2. Nodes need to be configured to allow insecure registries

## Solution

### Option 1: Configure Insecure Registry on K8s Nodes
On each worker node, add to `/etc/containerd/config.toml`:

```toml
[plugins."io.containerd.grpc.v1.cri".registry]
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."192.168.1.150:3000"]
      endpoint = ["http://192.168.1.150:3000"]
  [plugins."io.containerd.grpc.v1.cri".registry.configs]
    [plugins."io.containerd.grpc.v1.cri".registry.configs."192.168.1.150:3000".tls]
      insecure_skip_verify = true
```

Then restart containerd: `sudo systemctl restart containerd`

### Option 2: Use Docker Hub (Temporary)
Push images to Docker Hub instead of local registry.

### Option 3: Setup HTTPS for Forgejo Registry
Configure SSL certificates for the registry.
