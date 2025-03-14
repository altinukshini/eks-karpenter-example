data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.us_east_1
}

data "aws_subnet" "private_subnets" {
  count = length(var.private_subnet_ids)
  id    = var.private_subnet_ids[count.index]
}

data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_eks_cluster_auth" "cluster" {
  name       = module.eks.cluster_name
  depends_on = [module.eks.cluster_name]
}

data "aws_eks_cluster" "cluster" {
  name       = module.eks.cluster_name
  depends_on = [module.eks.cluster_name]
}
