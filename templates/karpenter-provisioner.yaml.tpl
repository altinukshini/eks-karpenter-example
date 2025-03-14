apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: ${provisioner_name}
spec:
  template:
    spec:
      # reference to the EC2NodeClass
      nodeClassRef:
        apiVersion: karpenter.k8s.aws/v1
        kind: EC2NodeClass
        name: default
        group: karpenter.k8s.aws
      
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["${architecture}"]
        
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        
        - key: karpenter.sh/capacity-type
          operator: In
          values: ${capacity_types}
        
        - key: node.kubernetes.io/instance-type
          operator: In
          values: ${instance_types}
      
      # preventing premature pod scheduling
      startupTaints:
        - key: node.kubernetes.io/not-ready
          effect: NoSchedule
  
  limits:
    cpu: 1000       # Maximum total CPU cores across all nodes
    memory: 1000Gi  # Maximum total memory across all nodes
  
  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: ${ttl_seconds_after_empty}s
  # periodic node replacement
  expireAfter: ${ttl_seconds_until_expired}s
