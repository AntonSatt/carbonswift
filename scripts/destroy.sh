#!/bin/bash
set -e

# CarbonShift Destroy Script
# This script destroys all infrastructure created by the deployment

echo "=========================================="
echo "  CarbonShift Destroy Script"
echo "=========================================="
echo ""

echo "⚠️  WARNING: This will destroy ALL infrastructure!"
echo ""
echo "The following resources will be DESTROYED:"
echo "  • All EC2 instances (web-server, api-server, compute-worker)"
echo "  • Security Group"
echo "  • IAM Role and Policies"
echo ""

read -p "Are you ABSOLUTELY SURE you want to destroy everything? (type 'yes' to confirm): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Destroy cancelled."
    exit 0
fi

echo ""
read -p "Please type 'destroy' to confirm one more time: " confirm2

if [ "$confirm2" != "destroy" ]; then
    echo "Destroy cancelled."
    exit 0
fi

echo ""
echo "Proceeding with infrastructure destruction..."
echo ""

cd terraform

terraform destroy -auto-approve

echo ""
echo "=========================================="
echo "  Infrastructure Destroyed Successfully"
echo "=========================================="
echo ""
echo "All AWS resources have been removed."
echo "Note: Grafana Cloud data and configurations were not affected."
echo ""
