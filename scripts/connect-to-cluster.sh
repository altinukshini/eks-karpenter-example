#!/bin/bash
# Script to connect to the EKS cluster and verify Karpenter installation

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
      echo "  --cluster-name CLUSTER_NAME  Name of the EKS cluster to connect to"
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

echo "Connecting to EKS cluster: $CLUSTER_NAME in region: $REGION"
echo ""
echo "Updating kubeconfig..."
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

echo ""
echo "Verifying connection to the cluster..."
kubectl get nodes

echo ""
echo "Checking Karpenter installation..."
kubectl get pods -n karpenter

echo ""
echo "Karpenter NodePools:"
kubectl get nodepools

echo ""
echo "Karpenter EC2NodeClasses:"
kubectl get ec2nodeclasses
