# Spot Instance Deployments

These examples demonstrate how to deploy workloads on AWS Spot instances for cost savings.

## How It Works

The key to Spot instance deployments is adding the `karpenter.sh/capacity-type: spot` label to your `nodeSelector`:

```yaml
nodeSelector:
  kubernetes.io/arch: amd64  # or arm64
  karpenter.sh/capacity-type: spot
```

## Best Practices

When using Spot instances:

1. Always use PodDisruptionBudgets (see examples in the `high-availability` directory)
2. Set appropriate replicas to ensure redundancy
3. Use topology spread constraints to distribute pods across multiple nodes
4. Implement proper handling for termination signals in your applications

Spot instances can be reclaimed by AWS with a 2-minute warning, so your applications should be designed to handle interruptions gracefully. 
