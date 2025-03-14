module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.34.0"

  cluster_name    = local.cluster_name
  cluster_version = var.eks.cluster_version

  vpc_id                   = var.vpc_id
  subnet_ids               = var.private_subnet_ids
  control_plane_subnet_ids = var.public_subnet_ids

  enable_irsa = true

  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  authentication_mode = "API_AND_CONFIG_MAP"

  cluster_endpoint_public_access       = var.eks.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.eks.cluster_endpoint_public_access_cidrs

  enable_cluster_creator_admin_permissions = true

  node_security_group_tags = {
    "karpenter.sh/discovery" = local.cluster_name
  }

  cluster_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description                = "Nodes on ephemeral ports"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  node_security_group_additional_rules = {
    # Allow all traffic between nodes for services like CoreDNS and cross-pod communication
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
  }

  eks_managed_node_group_defaults = local.eks_managed_node_group_defaults
  eks_managed_node_groups         = var.eks.managed_node_groups

  tags = local.tags
} 