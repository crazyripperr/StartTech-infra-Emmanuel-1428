#!/bin/bash
# deploy-infrastructure.sh
# Run this script to deploy/update all AWS infrastructure via Terraform.
# Usage: ./scripts/deploy-infrastructure.sh

set -e  # Exit immediately if any command fails

echo "🏗️  StartTech Infrastructure Deploy"
echo "======================================"

# Check required tools are installed
command -v terraform >/dev/null 2>&1 || { echo "❌ terraform not found. Install from https://terraform.io/downloads"; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "❌ aws CLI not found. Install from https://aws.amazon.com/cli/"; exit 1; }

# Check AWS credentials are configured
aws sts get-caller-identity > /dev/null 2>&1 || { echo "❌ AWS credentials not configured. Run 'aws configure'"; exit 1; }

echo "✅ AWS identity confirmed: $(aws sts get-caller-identity --query 'Arn' --output text)"

cd terraform

echo ""
echo "📦 Initialising Terraform..."
terraform init

echo ""
echo "✅ Validating configuration..."
terraform validate

echo ""
echo "📋 Planning changes..."
terraform plan -out=tfplan

echo ""
read -p "⚠️  Review the plan above. Apply changes? (yes/no): " CONFIRM

if [ "$CONFIRM" = "yes" ]; then
  echo ""
  echo "🚀 Applying infrastructure changes..."
  terraform apply tfplan

  echo ""
  echo "📤 Infrastructure outputs:"
  echo "──────────────────────────"
  echo "CloudFront URL:  https://$(terraform output -raw cloudfront_domain)"
  echo "ALB DNS:         $(terraform output -raw alb_dns_name)"
  echo "S3 Bucket:       $(terraform output -raw s3_bucket_name)"
  echo "CF Dist ID:      $(terraform output -raw cloudfront_distribution_id)"
  echo ""
  echo "✅ Infrastructure deployed successfully!"
else
  echo "❌ Deploy cancelled."
  rm -f tfplan
fi
