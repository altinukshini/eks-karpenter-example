# EKS with Karpenter - Terraform

⚠️ **This is an example project intended for educational and learning purposes. It should not be used directly in production without proper review and customization for your specific needs.**

This Terraform project deploys an Amazon EKS cluster with Karpenter for node autoscaling, supporting both x86 and ARM/Graviton instances with Spot instance capability

## Quick Start

```bash
export AWS_PROFILE=your-profile

cp terraform.tfvars.example terraform.tfvars
# Modify the VPC and subnets

# init, plan and apply
terraform init
terraform plan
terraform apply

# connect to EKS cluster
./scripts/connect-to-cluster.sh

# deploy sample workloads that will trigger Karpenter provisioning
kubectl apply -f examples/architecture/nginx-x86.yaml    # For x86/AMD64
kubectl apply -f examples/architecture/nginx-arm64.yaml  # For ARM64/Graviton

# or
./scripts/test-karpenter.sh

```

## Architecture

This project creates:

1. An EKS cluster in existing VPC using the [terraform-aws-modules/eks/aws](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest) community module
2. A small managed node group for system workloads
3. Karpenter for node autoscaling using the [terraform-aws-modules/eks/aws//modules/karpenter](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest/submodules/karpenter) community module
4. Karpenter NodePools for both x86 and ARM instances
5. IAM roles and policies for Karpenter and EKS

## Requirements

- AWS CLI configured with appropriate credentials
- Terraform >= 1.3.2
- kubectl
- An existing VPC with public and private subnets

## Configuration

This project supports two approaches for configuring Karpenter node provisioning:

### 1. Using Discovery with Tags (Default)

By default, the project uses discovery based on the `karpenter.sh/discovery` tag to automatically find subnets and security groups

The project automatically adds the `karpenter.sh/discovery: <cluster_name>` tag to all resources, which Karpenter uses to discover subnets and security groups

Example configuration in `terraform.tfvars`:

```hcl
use_subnet_discovery         = true
use_security_group_discovery = true
```

### 2. Using Explicit Subnet IDs and Security Group IDs

Alternatively, you can use explicit subnet IDs and security group IDs for Karpenter node provisioning by setting the following variables to false

```hcl
# Disable discovery
use_subnet_discovery         = false
use_security_group_discovery = false
```

## Terraform Remote State Management

By default, the project uses local terraform state. If you wish to set up remote state, follow the instructions below.

### Use the Setup Script

Use the helper script to create the S3 bucket and DynamoDB table

```bash
# run with default settings (will use terraform-state-<account-id>-<region> as bucket name)
./scripts/setup-remote-state.sh
```

The script will:
1. Create an S3 bucket with versioning and encryption enabled
2. Create a DynamoDB table for state locking
3. Output the exact configuration to add to your `backend.tf` file

## Running Workloads on Specific Architectures

### Testing Karpenter Provisioning

Helper script to test Karpenter's node provisioning capabilities:

```bash
# Run the test script
./scripts/test-karpenter.sh
```

The script will:
1. Deploy test workloads for x86, ARM, and Spot instances
2. Monitor node provisioning
3. Show Karpenter events and deployment status
4. Provide cleanup commands

### Applying Example Deployments

```bash
# Apply a specific example
kubectl apply -f examples/architecture/nginx-x86.yaml
kubectl apply -f examples/architecture/nginx-arm64.yaml

# Apply all examples in a directory
kubectl apply -f examples/architecture/

# Apply all examples
kubectl apply -f examples/
```

### Running on x86/AMD64, ARM64/Graviton, Spot Instances

The `examples/` directory contains organized sample deployments for various use cases:

- **[Architecture-specific deployments](examples/architecture/)** - Run workloads on x86/AMD64 or ARM64/Graviton
- **[Spot instance deployments](examples/spot/)** - Run workloads on cost-effective Spot instances
- **[Specialized workloads](examples/specialized/)** - Deploy compute-optimized, memory-intensive, or workloads with tolerations
- **[High availability configurations](examples/high-availability/)** - PodDisruptionBudgets for ensuring availability

Each directory contains detailed README files with usage instructions and explanations.

## CleanUp

Before destroying the infrastructure with Terraform, it's important to properly clean up Karpenter resources to avoid issues during deletion.

```bash
# Scale down all deployments to 0
kubectl get deployments --all-namespaces -o json | jq -r '.items[] | .metadata.name + " " + .metadata.namespace' | while read -r name namespace; do
  kubectl scale deployment "$name" --replicas=0 -n "$namespace"
done

# Delete Karpenter resources
kubectl delete nodeclaims --all
kubectl delete nodepools --all
kubectl delete ec2nodeclasses.karpenter.k8s.aws --all

# If resources are stuck with finalizers, you can force remove them
kubectl patch nodepools <NODEPOOL_NAME> -p '{"metadata":{"finalizers":[]}}' --type=merge
kubectl patch ec2nodeclasses <EC2NODECLASS_NAME> -p '{"metadata":{"finalizers":[]}}' --type=merge

# Check for any remaining nodes
kubectl get nodes -o wide

# Clean up IAM policies from Karpenter node role
NODE_ROLE_NAME="Karpenter-eks-karpenter-demo"
POLICIES=$(aws iam list-attached-role-policies --role-name "$NODE_ROLE_NAME" --query "AttachedPolicies[].PolicyArn" --output text)

for POLICY_ARN in $POLICIES; do
  aws iam detach-role-policy --role-name "$NODE_ROLE_NAME" --policy-arn "$POLICY_ARN"
done
```

After running the cleanup commands, we can safely destroy the infrastructure:

```bash
terraform destroy
```

## Karpenter Version

This project uses Karpenter v1.3.1, which is the latest stable version with the v1 API.

For more information on the Karpenter v1 API, see the [Karpenter documentation](https://karpenter.sh/docs/).

