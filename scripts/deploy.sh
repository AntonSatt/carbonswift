#!/bin/bash
set -e

# CarbonShift Deployment Script
# This script deploys the infrastructure and services for the CarbonShift project

echo "=========================================="
echo "  CarbonShift Deployment Script"
echo "=========================================="
echo ""

# Check prerequisites
echo "Checking prerequisites..."

command -v terraform >/dev/null 2>&1 || { echo "Error: terraform is not installed. Please install it first."; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "Error: AWS CLI is not installed. Please install it first."; exit 1; }

# Check AWS credentials
aws sts get-caller-identity >/dev/null 2>&1 || { echo "Error: AWS credentials not configured. Run 'aws configure' first."; exit 1; }

echo "✓ Prerequisites check passed"
echo ""

# Check if terraform.tfvars exists
if [ ! -f "terraform/terraform.tfvars" ]; then
    echo "Error: terraform/terraform.tfvars not found!"
    echo "Please copy terraform/terraform.tfvars.example to terraform/terraform.tfvars and fill in your values."
    exit 1
fi

echo "✓ terraform.tfvars found"
echo ""

# Navigate to terraform directory
cd terraform

echo "Step 1: Initializing Terraform..."
terraform init

echo ""
echo "Step 2: Validating Terraform configuration..."
terraform validate

echo ""
echo "Step 3: Planning infrastructure deployment..."
terraform plan -out=tfplan

echo ""
echo "=========================================="
echo "Ready to deploy infrastructure!"
echo "=========================================="
echo ""
echo "The following resources will be created:"
echo "  • 3x EC2 t3.micro instances (web-server, api-server, compute-worker)"
echo "  • Security Group with required ports"
echo "  • IAM Role with Amazon Bedrock permissions"
echo ""
read -p "Do you want to proceed with deployment? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo "Step 4: Deploying infrastructure..."
terraform apply tfplan

echo ""
echo "=========================================="
echo "  Deployment Complete!"
echo "=========================================="
echo ""

# Get outputs
echo "Fetching instance information..."
terraform output -json > ../outputs.json

WEB_IP=$(terraform output -raw web_server_public_ip)
API_IP=$(terraform output -raw api_server_public_ip)
COMPUTE_IP=$(terraform output -raw compute_worker_public_ip)

echo ""
echo "Instance Public IPs:"
echo "  • Web Server:     $WEB_IP"
echo "  • API Server:     $API_IP"
echo "  • Compute Worker: $COMPUTE_IP"
echo ""

echo "Carbon Service Endpoints:"
echo "  • Web Server Metrics:    http://$WEB_IP:8080/metrics"
echo "  • API Server Metrics:    http://$API_IP:8080/metrics"
echo "  • Compute Worker Metrics: http://$COMPUTE_IP:8080/metrics"
echo ""
echo "  • Web Server AI Insight:    http://$WEB_IP:8080/ai-insight"
echo "  • API Server AI Insight:    http://$API_IP:8080/ai-insight"
echo "  • Compute Worker AI Insight: http://$COMPUTE_IP:8080/ai-insight"
echo ""

echo "Node Exporter Endpoints:"
echo "  • Web Server:     http://$WEB_IP:9100/metrics"
echo "  • API Server:     http://$API_IP:9100/metrics"
echo "  • Compute Worker: http://$COMPUTE_IP:9100/metrics"
echo ""

echo "Note: It may take 5-10 minutes for all services to be fully operational."
echo "You can check the setup progress with:"
echo "  ssh ubuntu@$WEB_IP 'tail -f /var/log/user-data.log'"
echo ""

echo "Next Steps:"
echo "1. Wait for services to start (5-10 minutes)"
echo "2. Verify metrics are being collected in Grafana Cloud"
echo "3. Import the dashboard from grafana/dashboard.json"
echo "4. Configure AI Insight panels with the carbon service endpoints"
echo ""

echo "To test the Carbon Service:"
echo "  curl http://$WEB_IP:8080/metrics"
echo "  curl http://$WEB_IP:8080/ai-insight"
echo ""

echo "To simulate high load (for testing AI insights):"
echo "  ssh ubuntu@$COMPUTE_IP 'stress-ng --cpu 2 --timeout 300s'"
echo ""

echo "Deployment script completed successfully! 🎉"
