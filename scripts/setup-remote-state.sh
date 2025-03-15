#!/bin/bash
# Script to set up remote state infrastructure for Terraform

set -e

DEFAULT_REGION="us-west-2"
DEFAULT_BUCKET_PREFIX="terraform-state"
DEFAULT_TABLE="terraform-state-lock"

while [[ $# -gt 0 ]]; do
  case $1 in
    --region)
      REGION="$2"
      shift 2
      ;;
    --bucket)
      BUCKET_NAME="$2"
      shift 2
      ;;
    --table)
      TABLE_NAME="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [--region REGION] [--bucket BUCKET_NAME] [--table TABLE_NAME]"
      echo ""
      echo "Options:"
      echo "  --region REGION       AWS region to create resources in (default: $DEFAULT_REGION)"
      echo "  --bucket BUCKET_NAME  Name of S3 bucket to create (default: $DEFAULT_BUCKET_PREFIX-ACCOUNT_ID-REGION)"
      echo "  --table TABLE_NAME    Name of DynamoDB table to create (default: $DEFAULT_TABLE)"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

REGION=${REGION:-$DEFAULT_REGION}
TABLE_NAME=${TABLE_NAME:-$DEFAULT_TABLE}

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

if [ -z "$BUCKET_NAME" ]; then
  BUCKET_NAME="${DEFAULT_BUCKET_PREFIX}-${ACCOUNT_ID}-${REGION}"
fi

echo "Creating remote state infrastructure with the following settings:"
echo "  Region:        $REGION"
echo "  S3 Bucket:     $BUCKET_NAME"
echo "  DynamoDB Table: $TABLE_NAME"
echo ""
echo "Proceed? (y/n)"
read -r CONFIRM

if [[ $CONFIRM != "y" && $CONFIRM != "Y" ]]; then
  exit 0
fi

echo "Creating S3 bucket: $BUCKET_NAME"
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "Bucket already exists, skipping creation."
else
  aws s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION"

  echo "Enabling versioning on S3 bucket"
  aws s3api put-bucket-versioning \
      --bucket "$BUCKET_NAME" \
      --versioning-configuration Status=Enabled

  echo "Enabling encryption on S3 bucket"
  aws s3api put-bucket-encryption \
      --bucket "$BUCKET_NAME" \
      --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'

  echo "Adding bucket policy to block public access"
  aws s3api put-public-access-block \
      --bucket "$BUCKET_NAME" \
      --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
fi

echo "Creating DynamoDB table: $TABLE_NAME"
if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$REGION" 2>/dev/null; then
  echo "Table already exists, skipping creation."
else
  aws dynamodb create-table \
      --table-name "$TABLE_NAME" \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST \
      --region "$REGION"
fi

echo ""
echo "Update backend.tf file with the following configuration:"
echo ""
echo "terraform {"
echo "  backend \"s3\" {"
echo "    bucket         = \"$BUCKET_NAME\""
echo "    key            = \"eks-karpenter/terraform.tfstate\""
echo "    region         = \"$REGION\""
echo "    dynamodb_table = \"$TABLE_NAME\""
echo "    encrypt        = true"
echo "  }"
echo "}"
echo ""
echo "Then run: terraform init -reconfigure" 