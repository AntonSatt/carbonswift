#!/bin/bash

# CarbonShift Verification Script
# This script verifies that all services are running correctly

echo "=========================================="
echo "  CarbonShift Verification Script"
echo "=========================================="
echo ""

# Check if outputs.json exists
if [ ! -f "outputs.json" ]; then
    echo "Error: outputs.json not found!"
    echo "Please run the deployment script first."
    exit 1
fi

# Extract IPs from terraform outputs
cd terraform
WEB_IP=$(terraform output -raw web_server_public_ip 2>/dev/null)
API_IP=$(terraform output -raw api_server_public_ip 2>/dev/null)
COMPUTE_IP=$(terraform output -raw compute_worker_public_ip 2>/dev/null)
cd ..

if [ -z "$WEB_IP" ] || [ -z "$API_IP" ] || [ -z "$COMPUTE_IP" ]; then
    echo "Error: Could not retrieve instance IPs from Terraform."
    exit 1
fi

echo "Testing instances:"
echo "  • Web Server:     $WEB_IP"
echo "  • API Server:     $API_IP"
echo "  • Compute Worker: $COMPUTE_IP"
echo ""

# Function to test endpoint
test_endpoint() {
    local name=$1
    local url=$2
    local expected=$3
    
    echo -n "Testing $name... "
    
    response=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null)
    
    if [ "$response" = "$expected" ]; then
        echo "✓ OK (HTTP $response)"
        return 0
    else
        echo "✗ FAILED (HTTP $response, expected $expected)"
        return 1
    fi
}

# Function to test metrics content
test_metrics_content() {
    local name=$1
    local url=$2
    
    echo -n "Testing $name metrics content... "
    
    content=$(curl -s --max-time 5 "$url" 2>/dev/null)
    
    if echo "$content" | grep -q "grid_carbon_intensity_g_kwh"; then
        echo "✓ OK (contains carbon metrics)"
        return 0
    else
        echo "✗ FAILED (missing carbon metrics)"
        return 1
    fi
}

echo "=== Node Exporter Tests ==="
test_endpoint "Web Server Node Exporter" "http://$WEB_IP:9100/metrics" "200"
test_endpoint "API Server Node Exporter" "http://$API_IP:9100/metrics" "200"
test_endpoint "Compute Worker Node Exporter" "http://$COMPUTE_IP:9100/metrics" "200"

echo ""
echo "=== Carbon Service Tests ==="
test_endpoint "Web Server Carbon Service" "http://$WEB_IP:8080/health" "200"
test_endpoint "API Server Carbon Service" "http://$API_IP:8080/health" "200"
test_endpoint "Compute Worker Carbon Service" "http://$COMPUTE_IP:8080/health" "200"

echo ""
echo "=== Carbon Metrics Tests ==="
test_metrics_content "Web Server" "http://$WEB_IP:8080/metrics"
test_metrics_content "API Server" "http://$API_IP:8080/metrics"
test_metrics_content "Compute Worker" "http://$COMPUTE_IP:8080/metrics"

echo ""
echo "=== AI Insight Tests ==="
test_endpoint "Web Server AI Insight" "http://$WEB_IP:8080/ai-insight" "200"
test_endpoint "API Server AI Insight" "http://$API_IP:8080/ai-insight" "200"
test_endpoint "Compute Worker AI Insight" "http://$COMPUTE_IP:8080/ai-insight" "200"

echo ""
echo "=== Sample Data ==="
echo ""
echo "Sample Carbon Metrics (Web Server):"
curl -s "http://$WEB_IP:8080/metrics" | grep -E "(grid_carbon_intensity|instance_co2_emissions)" | head -10

echo ""
echo ""
echo "Sample AI Insight (Web Server):"
curl -s "http://$WEB_IP:8080/ai-insight" | jq '.' 2>/dev/null || curl -s "http://$WEB_IP:8080/ai-insight"

echo ""
echo "=========================================="
echo "  Verification Complete"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Check Grafana Cloud to verify metrics are being ingested"
echo "2. Import the dashboard from grafana/dashboard.json"
echo "3. Configure the AI Insight panels with your instance IPs"
echo ""
