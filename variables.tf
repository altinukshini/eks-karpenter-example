variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-2"
}

variable "vpc_id" {
  description = "ID of the VPC where the cluster will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the EKS cluster nodes"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "demo"
    Project     = "eks-karpenter-example"
    Terraform   = "true"
  }
}

variable "eks" {
  description = "EKS cluster configuration"
  type = object({
    cluster_name                         = string
    cluster_version                      = string
    cluster_endpoint_public_access       = bool
    cluster_endpoint_public_access_cidrs = list(string)
    managed_node_groups                  = map(any)
    managed_node_group_defaults          = any
  })
  default = {
    cluster_name                         = "eks-karpenter-demo"
    cluster_version                      = "1.30"
    cluster_endpoint_public_access       = true
    cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
    managed_node_groups = {
      system = {
        name           = "eks-system"
        instance_types = ["t4g.small"]
        ami_type       = "AL2_ARM_64"
        min_size       = 1
        max_size       = 3
        desired_size   = 2
        capacity_type  = "ON_DEMAND"
        lifecycle = {
          create_before_destroy = true
        }
      }
    }
    managed_node_group_defaults = {
      ami_type       = "AL2_ARM_64"
      instance_types = ["t4g.small"]
      disk_size      = 20
    }
  }
}

variable "karpenter" {
  description = "Karpenter configuration"
  type = object({
    version                      = string
    use_subnet_discovery         = bool
    use_security_group_discovery = bool
    node_pools                   = map(any)
    ami_family                   = string
    ami_selector_terms_alias     = string
  })
  default = {
    version                      = "v1.3.1"
    ami_family                   = "AL2023"
    ami_selector_terms_alias     = "al2023@latest"
    use_subnet_discovery         = true
    use_security_group_discovery = true
    node_pools = {
      x86 = {
        name = "default-x86"
        instance_types = [
          "t3.small", "t3a.small",
          "t3.medium", "t3a.medium",
          # x86 instances
          "m5.medium", "m5.large", "m5.xlarge",
          "c5.medium", "c5.large", "c5.xlarge",
          "r5.medium", "r5.large", "r5.xlarge",
          # Latest x86 instances
          "m6i.medium", "m6i.large", "m6i.xlarge",
          "c6i.medium", "c6i.large", "c6i.xlarge",
          "r6i.medium", "r6i.large", "r6i.xlarge"
        ]
        capacity_types            = ["spot", "on-demand"]
        architecture              = "amd64"
        os                        = "linux"
        ttl_seconds_after_empty   = 30
        ttl_seconds_until_expired = 2592000
        labels = {
          "kubernetes.io/arch"         = "amd64"
          "node-type"                  = "x86"
          "karpenter.sh/capacity-type" = "spot"
          "nodeManager"                = "karpenter"
        }
      },
      arm = {
        name = "default-arm"
        instance_types = [
          "t4g.small", "t4g.medium",
          # Graviton2 instances
          "m6g.medium", "m6g.large", "m6g.xlarge",
          "c6g.medium", "c6g.large", "c6g.xlarge",
          "r6g.medium", "r6g.large", "r6g.xlarge",
          # Graviton3 instances
          "m7g.medium", "m7g.large", "m7g.xlarge",
          "c7g.medium", "c7g.large", "c7g.xlarge",
          "r7g.medium", "r7g.large", "r7g.xlarge",
          # Graviton4 instances
          "m8g.medium", "m8g.large", "m8g.xlarge",
          "c8g.medium", "c8g.large", "c8g.xlarge",
          "r8g.medium", "r8g.large", "r8g.xlarge",
          "x8g.medium", "x8g.large", "x8g.xlarge"
        ]
        capacity_types            = ["spot", "on-demand"]
        architecture              = "arm64"
        os                        = "linux"
        ttl_seconds_after_empty   = 30
        ttl_seconds_until_expired = 2592000
        labels = {
          "kubernetes.io/arch"         = "arm64"
          "node-type"                  = "arm"
          "karpenter.sh/capacity-type" = "spot"
          "nodeManager"                = "karpenter"
        }
      }
    }
  }
}
