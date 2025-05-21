module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.vpc_name
  cidr = var.vpc.cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, length(var.vpc.private_subnets))
  private_subnets = var.vpc.private_subnets
  public_subnets  = var.vpc.public_subnets

  enable_nat_gateway     = var.vpc.enable_nat_gateway
  single_nat_gateway     = var.vpc.single_nat_gateway
  one_nat_gateway_per_az = var.vpc.one_nat_gateway_per_az

  enable_dns_hostnames = var.vpc.enable_dns_hostnames
  enable_dns_support   = var.vpc.enable_dns_support

  private_subnet_names = ["${local.vpc_name}-priv-1", "${local.vpc_name}-priv-2", "${local.vpc_name}-priv-3"]
  public_subnet_names  = ["${local.vpc_name}-pub-1", "${local.vpc_name}-pub-2", "${local.vpc_name}-pub-3"]

  private_subnet_tags = merge(
    {
      Tier = "private"
    },
    local.any_node_class_subnet_discovery ? {
      "karpenter.sh/discovery" = local.cluster_name
    } : {}
  )

  public_subnet_tags = {
    Tier = "public"
  }
}
