# CarbonShift - AI-Powered "What If" Carbon Dashboard

## Project Overview

CarbonShift is an AI-powered observability dashboard for the Grafana/AWS Hackathon that shows real-time CO2 emissions of AWS instances and compares them against other regions using Amazon Bedrock for intelligent optimization suggestions.

## Architecture

- **Infrastructure**: 3x t3.micro EC2 instances in eu-north-1 (Sweden)
  - web-server
  - api-server  
  - compute-worker

- **Monitoring Stack**:
  - Node Exporter (system metrics)
  - Grafana Alloy (metrics collection)
  - Grafana Cloud (visualization)

- **Carbon Service**: Python Flask app with:
  - `/metrics` - Prometheus metrics for carbon intensity from Nowtricity API
  - `/ai-insight` - AI-powered optimization suggestions via Amazon Bedrock

## Prerequisites

- AWS Account with permissions to create EC2 instances and IAM roles
- Terraform installed
- Grafana Cloud account
- Python 3.9+
- AWS CLI configured

## Project Structure

```
CarbonShift/
├── terraform/          # Infrastructure as Code
├── carbon-service/     # Python service for metrics and AI insights
├── grafana/           # Dashboard definitions
└── scripts/           # Deployment and utility scripts
```

## Quick Start

```bash
# 1. Configure Grafana Cloud credentials (see DEPLOYMENT.md)
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars with your values

# 2. Deploy infrastructure
./scripts/deploy.sh

# 3. Verify deployment (wait 5-10 minutes first)
./scripts/verify.sh

# 4. Import dashboard to Grafana Cloud
# Upload grafana/dashboard.json via Grafana UI
```

## Utility Scripts

- **`deploy.sh`** - Deploys all infrastructure (~10 minutes)
- **`verify.sh`** - Tests all endpoints and services
- **`destroy.sh`** - Tears down all AWS infrastructure (saves costs)

**Note**: The destroy → deploy cycle is completely safe. Your code and Grafana Cloud data are preserved.

## Key Features

- **Real-time Emissions**: Live CO2 tracking from Swedish data center
- **What-If Analysis**: Compare emissions across EU regions (SE, DE, GB, FR)
- **AI Insights**: Amazon Bedrock-powered optimization recommendations
- **Live Grid Data**: Current carbon intensity for all monitored regions
