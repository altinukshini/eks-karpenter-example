# Add the karpenter.sh/discovery tag to all resources that Karpenter needs to discover
# Workaround just to make sure that SG and Subnets provided via variables are tagged with karpenter.sh/discovery

resource "aws_ec2_tag" "subnet_karpenter_discovery" {
  count       = var.karpenter.use_subnet_discovery ? length(var.private_subnet_ids) : 0
  resource_id = var.private_subnet_ids[count.index]
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}

resource "aws_ec2_tag" "security_group_karpenter_discovery" {
  count       = var.karpenter.use_security_group_discovery ? 1 : 0
  resource_id = module.eks.node_security_group_id
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}

resource "aws_ec2_tag" "cluster_security_group_karpenter_discovery" {
  count       = var.karpenter.use_security_group_discovery ? 1 : 0
  resource_id = module.eks.cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}
