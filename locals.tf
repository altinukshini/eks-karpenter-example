locals {
  cluster_name = var.eks.cluster_name

  tags = merge(
    var.default_tags,
    {
      "cluster-name"                                = local.cluster_name
      "karpenter.sh/discovery"                      = local.cluster_name
      "kubernetes.io/cluster/${local.cluster_name}" = "owned"
    }
  )

  karpenter_namespace = "karpenter"
  karpenter_sa_name   = "karpenter"

  eks_managed_node_group_defaults = merge(
    var.eks.managed_node_group_defaults,
    {
      tags = local.tags
    }
  )

  available_azs   = data.aws_availability_zones.available.names
  subnet_zones    = try(data.aws_subnet.private_subnets[*].availability_zone, [])
  karpenter_zones = length(local.subnet_zones) > 0 ? local.subnet_zones : local.available_azs
}

