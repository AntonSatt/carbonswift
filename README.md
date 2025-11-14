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

1. Deploy infrastructure: `cd terraform && terraform apply`
2. Deploy carbon service: `cd carbon-service && ./deploy.sh`
3. Import Grafana dashboard from `grafana/dashboard.json`

## Key Features

- **Real-time Emissions**: Live CO2 tracking from Swedish data center
- **What-If Analysis**: Compare emissions across EU regions (SE, DE, GB, FR)
- **AI Insights**: Amazon Bedrock-powered optimization recommendations
- **Live Grid Data**: Current carbon intensity for all monitored regions
