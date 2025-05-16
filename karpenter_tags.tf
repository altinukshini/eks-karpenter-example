# Add the karpenter.sh/discovery tag to all resources that Karpenter needs to discover
# Workaround just to make sure that SG and Subnets provided via variables are tagged with karpenter.sh/discovery

locals {
  # Check if any node class has subnet discovery enabled
  any_node_class_subnet_discovery = length([
    for node_class in var.karpenter.ec2_node_classes :
    node_class if node_class.use_subnet_discovery == true
  ]) > 0

  # Check if any node class has security group discovery enabled
  any_node_class_sg_discovery = length([
    for node_class in var.karpenter.ec2_node_classes :
    node_class if node_class.use_security_group_discovery == true
  ]) > 0
}

resource "aws_ec2_tag" "subnet_karpenter_discovery" {
  count       = local.any_node_class_subnet_discovery ? length(module.vpc.private_subnets) : 0
  resource_id = module.vpc.private_subnets[count.index]
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}

resource "aws_ec2_tag" "security_group_karpenter_discovery" {
  count       = local.any_node_class_sg_discovery ? 1 : 0
  resource_id = module.eks.node_security_group_id
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}

resource "aws_ec2_tag" "cluster_security_group_karpenter_discovery" {
  count       = local.any_node_class_sg_discovery ? 1 : 0
  resource_id = module.eks.cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = local.cluster_name
}
