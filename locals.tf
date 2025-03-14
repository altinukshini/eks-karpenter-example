locals {
  cluster_name = var.cluster_name

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
    var.eks_managed_node_group_defaults,
    {
      tags = local.tags
    }
  )
}
