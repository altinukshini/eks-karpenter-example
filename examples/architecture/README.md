# Architecture-Specific Deployments

These examples demonstrate how to deploy workloads on specific CPU architectures (x86/AMD64 and ARM64/Graviton) using Karpenter for node provisioning

## How It Works

Karpenter can provision nodes with different CPU architectures based on your workload requirements. The key is to use the `kubernetes.io/arch` label in your `nodeSelector`:

```yaml
nodeSelector:
  kubernetes.io/arch: amd64  # For x86/AMD64 instances
```

or

```yaml
nodeSelector:
  kubernetes.io/arch: arm64  # For ARM64/Graviton instances
```
