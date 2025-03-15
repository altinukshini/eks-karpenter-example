#!/bin/bash
# Script to test Karpenter by deploying workloads and monitoring node provisioning

set -e

DEFAULT_REGION=$(aws configure get region || echo "us-west-2")

while [[ $# -gt 0 ]]; do
  case $1 in
    --region)
      REGION="$2"
      shift 2
      ;;
    --cluster-name)
      CLUSTER_NAME="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [--region REGION] [--cluster-name CLUSTER_NAME]"
      echo ""
      echo "Options:"
      echo "  --region REGION              AWS region where the cluster is deployed (default: from AWS CLI config)"
      echo "  --cluster-name CLUSTER_NAME  Name of the EKS cluster to test"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

REGION=${REGION:-$DEFAULT_REGION}

# If cluster name is not provided, try to get it from terraform output
if [ -z "$CLUSTER_NAME" ]; then
  if command -v terraform &> /dev/null; then
    echo "Cluster name not provided, attempting to get it from terraform output..."
    CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "")
  fi
  
  if [ -z "$CLUSTER_NAME" ]; then
    echo "Error: Cluster name not provided and could not be determined from terraform output."
    echo "Please provide the cluster name using --cluster-name or run this script from the terraform directory."
    exit 1
  fi
fi

echo "Testing Karpenter on EKS cluster: $CLUSTER_NAME in region: $REGION"

# Update kubeconfig
echo "Updating kubeconfig..."
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

# Check if Karpenter is installed
echo "Checking Karpenter installation..."
if ! kubectl get pods -n karpenter &>/dev/null; then
  echo "Error: Karpenter is not installed or not accessible."
  exit 1
fi

echo "Checking Karpenter NodePools..."
kubectl get nodepools

echo "Checking Karpenter EC2NodeClasses..."
kubectl get ec2nodeclasses

echo "Deploying test workloads..."

echo "Applying architecture-specific deployments..."
kubectl apply -f examples/architecture/nginx-x86.yaml
kubectl apply -f examples/architecture/nginx-arm64.yaml

echo "Applying spot instance deployments..."
kubectl apply -f examples/spot/nginx-spot-x86.yaml
kubectl apply -f examples/spot/nginx-spot-arm64.yaml

echo "Applying high-availability configurations..."
kubectl apply -f examples/high-availability/nginx-spot-arm64-pdb.yaml

echo "Test deployments created. Monitoring node provisioning..."

echo "Waiting for nodes to be provisioned (this may take a few minutes)..."
for i in {1..12}; do
  echo "Check $i/12 - Current nodes:"
  kubectl get nodes -L kubernetes.io/arch,karpenter.sh/capacity-type
  
  PENDING_PODS=$(kubectl get pods | grep -c "Pending" || true)
  if [ "$PENDING_PODS" -eq 0 ]; then
    echo "All pods are running! Karpenter has successfully provisioned the required nodes."
    break
  fi
  
  if [ $i -eq 12 ]; then
    echo "Some pods are still pending after 6 minutes. Check Karpenter logs for issues:"
    echo "kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter -c controller"
  else
    echo "Some pods are still pending. Waiting 30 seconds before next check..."
    sleep 30
  fi
done

echo "Karpenter events:"
kubectl get events --field-selector involvedObject.name=default-x86,reason=ProvisionedNode
kubectl get events --field-selector involvedObject.name=default-arm,reason=ProvisionedNode

echo "Test deployments:"
kubectl get deployments | grep nginx

echo ""
echo "Test complete. To clean up test resources, run:"
echo "kubectl delete -f examples/architecture/"
echo "kubectl delete -f examples/spot/"
echo "kubectl delete -f examples/high-availability/"
echo ""
echo "To monitor the deployments:"
echo "kubectl get deployments"
echo ""
echo "To monitor Karpenter logs:"
echo "kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter -c controller"
echo ""
echo "To monitor Karpenter node provisioning:"
echo "kubectl get nodes -L kubernetes.io/arch,karpenter.sh/capacity-type"

