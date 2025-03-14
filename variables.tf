variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-karpenter-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.29"
}

variable "karpenter_version" {
  description = "Version of Karpenter to deploy"
  type        = string
  default     = "v1.3.1"
}

variable "vpc_id" {
  description = "ID of the VPC where the cluster will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the EKS cluster nodes"
  type        = list(string)
  default     = []
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "use_subnet_discovery" {
  description = "Whether to use subnet discovery based on tags instead of explicit subnet IDs"
  type        = bool
  default     = true
}

variable "use_security_group_discovery" {
  description = "Whether to use security group discovery based on tags instead of explicit security group IDs"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Whether to enable public access to the EKS cluster endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks to allow public access to the EKS cluster endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "demo"
    Project     = "eks-karpenter"
    Terraform   = "true"
    Owner       = "platform-team"
  }
}

variable "eks_managed_node_groups" {
  description = "Map of EKS managed node group definitions to create"
  type        = any
  default = {
    system = {
      name           = "eks-system"
      instance_types = ["t4g.small"]
      ami_type       = "AL2_ARM_64" # ARM AMI type for Graviton instances
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      capacity_type  = "ON_DEMAND"

      lifecycle = {
        create_before_destroy = true
      }
    }
  }
}

variable "eks_managed_node_group_defaults" {
  description = "Map of EKS managed node group default configurations"
  type        = any
  default = {
    ami_type       = "AL2_ARM_64"
    instance_types = ["t4g.small"]
    disk_size      = 50
  }
}

variable "karpenter_node_instance_types" {
  description = "List of instance types that Karpenter can provision"
  type        = list(string)
  default = [
    # x86 instances
    "m5.large", "m5.xlarge", "m5.2xlarge",
    "c5.large", "c5.xlarge", "c5.2xlarge",
    "r5.large", "r5.xlarge", "r5.2xlarge",
    # Latest x86 instances
    "m6i.large", "m6i.xlarge", "m6i.2xlarge",
    "c6i.large", "c6i.xlarge", "c6i.2xlarge",
    "r6i.large", "r6i.xlarge", "r6i.2xlarge",
    # ARM/Graviton instances
    "m6g.large", "m6g.xlarge", "m6g.2xlarge",
    "c6g.large", "c6g.xlarge", "c6g.2xlarge",
    "r6g.large", "r6g.xlarge", "r6g.2xlarge",
    # Latest ARM/Graviton instances
    "m7g.large", "m7g.xlarge", "m7g.2xlarge",
    "c7g.large", "c7g.xlarge", "c7g.2xlarge",
    "r7g.large", "r7g.xlarge", "r7g.2xlarge",
    # Graviton4 instances
    "m8g.large", "m8g.xlarge", "m8g.2xlarge",
    "c8g.large", "c8g.xlarge", "c8g.2xlarge",
    "r8g.large", "r8g.xlarge", "r8g.2xlarge",
    "x8g.large", "x8g.xlarge", "x8g.2xlarge"
  ]
}

variable "karpenter_node_capacity_types" {
  description = "List of capacity types that Karpenter can use (SPOT, ON_DEMAND)"
  type        = list(string)
  default     = ["SPOT", "ON_DEMAND"]
}

variable "karpenter_ttl_seconds_after_empty" {
  description = "Number of seconds Karpenter should wait before terminating an empty node"
  type        = number
  default     = 30
}

variable "karpenter_ttl_seconds_until_expired" {
  description = "Number of seconds a node can live before being replaced by Karpenter"
  type        = number
  default     = 2592000 # 30 days
}
