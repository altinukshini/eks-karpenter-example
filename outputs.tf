output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "The endpoint for the EKS cluster API server"
  value       = module.eks.cluster_endpoint
}


output "cluster_version" {
  description = "The Kubernetes version for the EKS cluster"
  value       = module.eks.cluster_version
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = module.eks.node_security_group_id
}

output "karpenter_irsa_arn" {
  description = "IAM role ARN for Karpenter service account"
  value       = module.karpenter.iam_role_arn
}

output "karpenter_instance_profile_name" {
  description = "Instance profile name for Karpenter nodes"
  value       = module.karpenter.instance_profile_name
}

output "karpenter_queue_name" {
  description = "SQS queue name for Karpenter node interruption handling"
  value       = module.karpenter.queue_name
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "vpc_id" {
  description = "VPC ID used for the EKS cluster"
  value       = var.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs used for the EKS cluster"
  value       = var.private_subnet_ids
}

output "subnet_discovery_enabled" {
  description = "Whether subnet discovery is enabled"
  value       = var.karpenter.use_subnet_discovery ? "Using subnet discovery with karpenter.sh/discovery tag" : "Using explicit subnet IDs"
}

output "public_subnet_ids" {
  description = "Public subnet IDs used for the EKS cluster"
  value       = var.public_subnet_ids
}

output "configure_kubectl" {
  description = "Configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "karpenter_version" {
  description = "Installed Karpenter version"
  value       = var.karpenter.version
}

output "karpenter_commands" {
  description = "Karpenter commands"
  value = {
    view_nodepools                         = "kubectl get nodepools"
    view_ec2nodeclasses                    = "kubectl get ec2nodeclasses"
    view_nodes                             = "kubectl get nodes -L kubernetes.io/arch,karpenter.sh/capacity-type"
    view_karpenter_logs                    = "kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter -c controller"
    example_deployment_apply_x86_example   = "kubectl apply -f examples/architecture/nginx-x86.yaml"
    example_deployment_apply_arm64_example = "kubectl apply -f examples/architecture/nginx-arm64.yaml"
  }
}