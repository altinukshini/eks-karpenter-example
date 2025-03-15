# High Availability with PodDisruptionBudgets

These examples demonstrate how to use PodDisruptionBudgets (PDBs) to ensure high availability during voluntary disruptions.

## How It Works

PodDisruptionBudgets limit the number of pods that can be down simultaneously during voluntary disruptions like:
- Node draining during cluster upgrades
- Node termination due to Karpenter's consolidation
- Spot instance reclamation

### minAvailable vs maxUnavailable

You can configure PDBs in two ways:

1. **minAvailable**: Ensures a minimum number of pods remain available
   ```yaml
   spec:
     minAvailable: 1  # At least 1 pod must remain available
   ```

2. **maxUnavailable**: Limits the maximum number of pods that can be unavailable
   ```yaml
   spec:
     maxUnavailable: 1  # At most 1 pod can be unavailable
   ```

## Best Practices

- Always use PDBs for critical workloads, especially on Spot instances
- For stateful applications, use `minAvailable: 1` to ensure data availability
- For stateless applications with multiple replicas, use `maxUnavailable: 25%` to allow for rolling updates
- Ensure your PDB selector matches the labels in your deployment 
