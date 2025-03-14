module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.34.0"

  cluster_name = module.eks.cluster_name

  # Enable v1 permissions for Karpenter
  enable_v1_permissions = true

  irsa_oidc_provider_arn          = module.eks.oidc_provider_arn
  irsa_namespace_service_accounts = ["${local.karpenter_namespace}:${local.karpenter_sa_name}"]

  enable_irsa = true

  create_instance_profile = true

  node_iam_role_additional_policies = {
    # Enables nodes to join EKS clusters and communicate with control plane
    AmazonEKSWorkerNodePolicy = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    # Allows pulling container images from ECR - required for system components
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    # Required for VPC CNI plugin to manage pod networking
    AmazonEKS_CNI_Policy = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    # Provides secure shell access and remote management capabilities
    # Recommended by AWS for node management and troubleshooting
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    # Enables sending logs and metrics to CloudWatch for monitoring
    # CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
    # Allows EBS volume management for persistent storage
    # AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  }

  # Enable spot termination handling
  enable_spot_termination = true

  # Node termination queue name
  queue_name = "karpenter-${module.eks.cluster_name}"

  tags = local.tags

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
  version             = trimprefix(var.karpenter_version, "v")

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
  version             = trimprefix(var.karpenter_version, "v")

  set {
    name  = "settings.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "settings.clusterEndpoint"
    value = module.eks.cluster_endpoint
  }

  set {
    name  = "settings.interruptionQueue"
    value = module.karpenter.queue_name
  }

  set {
    name  = "serviceAccount.name"
    value = module.karpenter.service_account
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter.iam_role_arn
  }

  set {
    name  = "controller.resources.requests.cpu"
    value = "250m"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "512Mi"
  }

  set {
    name  = "controller.resources.limits.cpu"
    value = "1"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "1Gi"
  }

  set {
    name  = "replicas"
    value = "1"
  }

  set {
    name  = "controller.logLevel"
    value = "info"
  }

  depends_on = [
    module.eks,
    helm_release.karpenter_crds
  ]
}

resource "kubectl_manifest" "karpenter_nodepool_x86" {
  yaml_body = templatefile("${path.module}/templates/karpenter-provisioner.yaml.tpl", {
    provisioner_name          = "default-x86"
    architecture              = "amd64"
    ttl_seconds_after_empty   = var.karpenter_ttl_seconds_after_empty
    ttl_seconds_until_expired = var.karpenter_ttl_seconds_until_expired

    # Filter instance types for x86 architecture
    instance_types = jsonencode([
      for type in var.karpenter_node_instance_types : type
      if !contains(["g", "gd", "gr"], substr(split(".", type)[0], length(split(".", type)[0]) - 1, 1))
    ])

    capacity_types = jsonencode(var.karpenter_node_capacity_types)
  })

  depends_on = [
    helm_release.karpenter,
    kubectl_manifest.karpenter_ec2nodeclass
  ]
}

resource "kubectl_manifest" "karpenter_nodepool_arm" {
  yaml_body = templatefile("${path.module}/templates/karpenter-provisioner.yaml.tpl", {
    provisioner_name          = "default-arm"
    architecture              = "arm64"
    ttl_seconds_after_empty   = var.karpenter_ttl_seconds_after_empty
    ttl_seconds_until_expired = var.karpenter_ttl_seconds_until_expired

    # Filter instance types for ARM architecture
    instance_types = jsonencode([
      for type in var.karpenter_node_instance_types : type
      if contains(["g", "gd", "gr"], substr(split(".", type)[0], length(split(".", type)[0]) - 1, 1))
    ])

    capacity_types = jsonencode(var.karpenter_node_capacity_types)
  })

  depends_on = [
    helm_release.karpenter,
    kubectl_manifest.karpenter_ec2nodeclass
  ]
}

resource "kubectl_manifest" "karpenter_ec2nodeclass" {
  yaml_body = templatefile("${path.module}/templates/karpenter-node-template.yaml.tpl", {
    cluster_name = module.eks.cluster_name
    node_role    = module.karpenter.node_iam_role_arn

    # Determine whether to use subnet IDs or subnet discovery
    use_subnet_ids = length(var.private_subnet_ids) > 0 && !var.use_subnet_discovery
    subnet_ids     = jsonencode(var.private_subnet_ids)

    # Determine whether to use security group IDs or security group discovery
    use_security_group_ids = !var.use_security_group_discovery
    security_group_ids     = jsonencode([module.eks.node_security_group_id])
  })

  depends_on = [
    helm_release.karpenter
  ]
}