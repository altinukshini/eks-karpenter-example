module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.34.0"

  cluster_name                    = module.eks.cluster_name
  enable_v1_permissions           = true
  irsa_oidc_provider_arn          = module.eks.oidc_provider_arn
  irsa_namespace_service_accounts = ["${local.karpenter_namespace}:${local.karpenter_sa_name}"]
  enable_irsa                     = true
  create_instance_profile         = true
  enable_spot_termination         = true
  queue_name                      = module.eks.cluster_name

  node_iam_role_additional_policies = {
    # Enables nodes to join EKS clusters and communicate with control plane
    AmazonEKSWorkerNodePolicy = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    # Allows pulling container images from ECR - required for system components
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    # Required for VPC CNI plugin to manage pod networking
    AmazonEKS_CNI_Policy = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    # Provides secure shell access and remote management capabilities
    # Recommended by AWS for node management and troubleshooting
    AmazonSSMManagedInstanceCore = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
    # Enables sending logs and metrics to CloudWatch for monitoring
    # CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
    # Allows EBS volume management for persistent storage
    # AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  }

  tags       = local.tags
  depends_on = [module.eks]
}

resource "helm_release" "karpenter_crds" {
  namespace        = "karpenter"
  create_namespace = true

  name                = "karpenter-crd"
  repository          = "oci://public.ecr.aws/karpenter"
  chart               = "karpenter-crd"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  version             = trimprefix(var.karpenter.version, "v")

  depends_on = [
    module.eks
  ]
}

resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true

  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  chart               = "karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  version             = trimprefix(var.karpenter.version, "v")

  values = [
    <<-EOT
    replicas: 1
    serviceAccount:
      name: ${module.karpenter.service_account}
      annotations:
        eks.amazonaws.com/role-arn: ${module.karpenter.iam_role_arn}
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    controller:
      logLevel: info
      resources:
        limits:
          cpu: 1
          memory: 1Gi
        requests:
          cpu: 250m
          memory: 512Mi
    EOT
  ]

  depends_on = [
    module.eks,
    helm_release.karpenter_crds
  ]
}

resource "kubectl_manifest" "karpenter_ec2nodeclass" {
  server_side_apply = true
  force_conflicts   = true

  yaml_body = templatefile("${path.module}/templates/karpenter-node-template.yaml.tpl", {
    cluster_name = module.eks.cluster_name
    node_role    = module.karpenter.node_iam_role_arn

    ami_family               = var.karpenter.ami_family
    ami_selector_terms_alias = var.karpenter.ami_selector_terms_alias

    # Determine whether to use subnet IDs or subnet discovery
    use_subnet_ids = length(var.private_subnet_ids) > 0 && !var.karpenter.use_subnet_discovery
    subnet_ids     = jsonencode(var.private_subnet_ids)

    # Determine whether to use security group IDs or security group discovery
    use_security_group_ids = !var.karpenter.use_security_group_discovery
    security_group_ids     = jsonencode([module.eks.node_security_group_id])
  })

  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_node_pool" {
  for_each = var.karpenter.node_pools

  server_side_apply = true
  force_conflicts   = true

  yaml_body = <<-YAML
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: ${each.value.name}
spec:
  template:
    metadata:
      labels: ${jsonencode(lookup(each.value, "labels", {}))}
    spec:
      nodeClassRef:
        kind: EC2NodeClass
        name: default
        group: karpenter.k8s.aws
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["${each.value.architecture}"]
        - key: kubernetes.io/os
          operator: In
          values: ["${each.value.os}"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ${jsonencode(each.value.capacity_types)}
        - key: node.kubernetes.io/instance-type
          operator: In
          values: ${jsonencode(each.value.instance_types)}
        ${length(local.karpenter_zones) > 0 ? "- key: topology.kubernetes.io/zone\n          operator: In\n          values: ${jsonencode(local.karpenter_zones)}" : ""}
      startupTaints:
        - key: node.kubernetes.io/not-ready
          effect: NoSchedule
      expireAfter: ${each.value.ttl_seconds_until_expired}s
  limits:
    cpu: "1000"
    memory: "1000Gi"
  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: ${each.value.ttl_seconds_after_empty}s
YAML

  depends_on = [
    helm_release.karpenter,
    kubectl_manifest.karpenter_ec2nodeclass
  ]
}
