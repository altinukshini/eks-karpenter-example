# Specialized Workload Deployments

These examples demonstrate how to deploy specialized workloads with specific requirements.

## How It Works

### Specific Instance Types

You can request specific instance types using the `node.kubernetes.io/instance-type` selector:

```yaml
nodeSelector:
  node.kubernetes.io/instance-type: c5.medium
```

### Tolerations

Tolerations allow pods to be scheduled on nodes with matching taints:

```yaml
tolerations:
- key: "workload-type"
  operator: "Equal"
  value: "specialized"
  effect: "NoSchedule"
```

### Memory-Intensive Workloads

For memory-intensive workloads, set high memory requests to target memory-optimized instances:

```yaml
resources:
  requests:
    memory: 16Gi
    cpu: 2
```

Combined with the ARM64 architecture selector, this will favor Graviton memory-optimized instances like r8g and x8g. 