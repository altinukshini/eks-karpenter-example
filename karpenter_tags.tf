# Add the karpenter.sh/discovery tag to all resources that Karpenter needs to discover
# Workaround just to make sure that SG and Subnets provided via variables are tagged

resource "aws_ec2_tag" "subnet_karpenter_discovery" {
  count       = length(var.private_subnet_ids)
  resource_id = var.private_subnet_ids[count.index]
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}

resource "aws_ec2_tag" "security_group_karpenter_discovery" {
  resource_id = module.eks.node_security_group_id
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}

resource "aws_ec2_tag" "cluster_security_group_karpenter_discovery" {
  resource_id = module.eks.cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}
