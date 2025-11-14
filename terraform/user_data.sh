#!/bin/bash
set -e

# Log all output
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting CarbonShift instance setup for role: ${role}"

# Update system
apt-get update
apt-get upgrade -y

# Install prerequisites
apt-get install -y \
    curl \
    wget \
    git \
    python3 \
    python3-pip \
    python3-venv \
    stress-ng \
    jq \
    unzip

# Install Node Exporter
echo "Installing Node Exporter..."
NODE_EXPORTER_VERSION="1.7.0"
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v$${NODE_EXPORTER_VERSION}/node_exporter-$${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
tar xvfz node_exporter-$${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
cp node_exporter-$${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-$${NODE_EXPORTER_VERSION}*

# Create Node Exporter systemd service
cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=root
ExecStart=/usr/local/bin/node_exporter --collector.systemd

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

# Install Grafana Alloy
echo "Installing Grafana Alloy..."
mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list
apt-get update
apt-get install -y alloy

# Configure Grafana Alloy
cat > /etc/alloy/config.alloy <<EOF
// Prometheus metrics scraping configuration
prometheus.scrape "default" {
  targets = [
    {
      "__address__" = "localhost:9100",
      "job"         = "node-exporter",
      "role"        = "${role}",
      "instance"    = "${role}",
    },
    {
      "__address__" = "localhost:8080",
      "job"         = "carbon-service",
      "role"        = "${role}",
      "instance"    = "${role}",
    },
  ]
  
  forward_to = [prometheus.remote_write.grafana_cloud.receiver]
  
  scrape_interval = "15s"
}

// Remote write to Grafana Cloud
prometheus.remote_write "grafana_cloud" {
  endpoint {
    url = "${grafana_cloud_url}"
    
    basic_auth {
      username = "${grafana_cloud_user}"
      password = "${grafana_cloud_key}"
    }
  }
}
EOF

systemctl enable alloy
systemctl start alloy

# Install AWS CLI v2
echo "Installing AWS CLI v2..."
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Create carbon service directory
mkdir -p /opt/carbon-service
cd /opt/carbon-service

# Create Python virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
pip install --upgrade pip
pip install flask requests boto3 prometheus-client

# Create the carbon service application
cat > /opt/carbon-service/app.py <<'PYEOF'
import os
import time
import logging
import requests
import json
from datetime import datetime, timedelta
from flask import Flask, Response, jsonify, request
from prometheus_client import Gauge, generate_latest, REGISTRY
import boto3
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Prometheus metrics
grid_carbon_intensity = Gauge(
    'grid_carbon_intensity_g_kwh',
    'Carbon intensity of electricity grid in gCO2/kWh',
    ['country']
)

co2_emissions = Gauge(
    'instance_co2_emissions_g_hour',
    'Estimated CO2 emissions in grams per hour',
    ['role', 'country']
)

# Constants
T3_MICRO_TDP_WATTS = 7.0  # Average power consumption for t3.micro
COUNTRIES = {
    'SE': 'Sweden',
    'DE': 'Germany',
    'GB': 'United Kingdom',
    'FR': 'France'
}
NOWTRICITY_API = "https://api.nowtricity.com/v1"

# Get instance role from metadata
try:
    role = requests.get('http://169.254.169.254/latest/meta-data/tags/instance/Role', timeout=2).text
except:
    role = os.environ.get('INSTANCE_ROLE', 'unknown')

logger.info(f"Carbon Service starting for role: {role}")

# Cache for carbon intensity data
carbon_cache = {}
cache_timestamp = 0
CACHE_TTL = 300  # 5 minutes


def fetch_carbon_intensity():
    """Fetch carbon intensity data from Nowtricity API"""
    global carbon_cache, cache_timestamp
    
    current_time = time.time()
    if current_time - cache_timestamp < CACHE_TTL and carbon_cache:
        logger.debug("Using cached carbon intensity data")
        return carbon_cache
    
    logger.info("Fetching fresh carbon intensity data from Nowtricity API")
    results = {}
    
    for country_code in COUNTRIES.keys():
        try:
            # Fetch last 24h average
            end_time = datetime.utcnow()
            start_time = end_time - timedelta(hours=24)
            
            url = f"{NOWTRICITY_API}/carbon-intensity/{country_code}"
            params = {
                'start': start_time.isoformat() + 'Z',
                'end': end_time.isoformat() + 'Z'
            }
            
            response = requests.get(url, params=params, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                if data and len(data) > 0:
                    # Calculate average
                    values = [item.get('intensity', 0) for item in data if 'intensity' in item]
                    avg_intensity = sum(values) / len(values) if values else 0
                    results[country_code] = avg_intensity
                    logger.info(f"{country_code}: {avg_intensity:.2f} gCO2/kWh")
                else:
                    # Fallback values based on typical grid mix
                    fallback = {'SE': 25, 'DE': 420, 'GB': 250, 'FR': 60}
                    results[country_code] = fallback.get(country_code, 100)
                    logger.warning(f"No data for {country_code}, using fallback: {results[country_code]}")
            else:
                # Fallback values
                fallback = {'SE': 25, 'DE': 420, 'GB': 250, 'FR': 60}
                results[country_code] = fallback.get(country_code, 100)
                logger.warning(f"API error for {country_code}, using fallback: {results[country_code]}")
                
        except Exception as e:
            logger.error(f"Error fetching data for {country_code}: {e}")
            fallback = {'SE': 25, 'DE': 420, 'GB': 250, 'FR': 60}
            results[country_code] = fallback.get(country_code, 100)
    
    carbon_cache = results
    cache_timestamp = current_time
    return results


def calculate_co2_emissions(carbon_intensity_g_kwh):
    """Calculate CO2 emissions in grams per hour"""
    # Power in kW
    power_kw = T3_MICRO_TDP_WATTS / 1000.0
    # CO2 in grams per hour = power (kW) * carbon intensity (g/kWh)
    co2_g_hour = power_kw * carbon_intensity_g_kwh
    return co2_g_hour


@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    try:
        intensities = fetch_carbon_intensity()
        
        # Update grid carbon intensity metrics
        for country_code, intensity in intensities.items():
            grid_carbon_intensity.labels(country=country_code).set(intensity)
        
        # Calculate and set CO2 emissions for each country
        for country_code, intensity in intensities.items():
            emissions = calculate_co2_emissions(intensity)
            co2_emissions.labels(role=role, country=country_code).set(emissions)
        
        return Response(generate_latest(REGISTRY), mimetype='text/plain')
    except Exception as e:
        logger.error(f"Error generating metrics: {e}")
        return Response(f"Error: {str(e)}", status=500)


@app.route('/ai-insight')
def ai_insight():
    """AI-powered optimization insights using Amazon Bedrock"""
    try:
        logger.info("AI insight endpoint called")
        
        # Get Grafana Cloud Prometheus URL from query params or config
        grafana_prom_url = request.args.get('prometheus_url', os.environ.get('GRAFANA_PROMETHEUS_URL', ''))
        
        # Query current CO2 emissions (simplified - in production, query Grafana Cloud)
        intensities = fetch_carbon_intensity()
        current_intensity = intensities.get('SE', 25)
        current_emissions = calculate_co2_emissions(current_intensity)
        
        # Determine if emissions are high (simplified logic)
        threshold = 3.0  # grams per hour
        is_high = current_emissions > threshold
        
        # Prepare prompt for Bedrock
        if is_high:
            prompt = f"""Act as an expert Site Reliability Engineer (SRE) specializing in cloud infrastructure optimization and sustainability.

Context:
- Instance role: {role}
- Current CO2 emissions: {current_emissions:.2f} g/hour
- Current grid carbon intensity (Sweden): {current_intensity:.2f} gCO2/kWh
- Instance type: t3.micro (AWS)
- Location: eu-north-1 (Stockholm, Sweden)

The CO2 emissions for this '{role}' instance are currently elevated at {current_emissions:.2f} g/hour.

Provide:
1. The most likely cause for elevated emissions
2. One specific, actionable optimization recommendation
3. Expected impact

Keep the response concise (max 150 words) and technical."""
        else:
            prompt = f"""Act as an expert Site Reliability Engineer (SRE) specializing in cloud infrastructure optimization and sustainability.

Context:
- Instance role: {role}
- Current CO2 emissions: {current_emissions:.2f} g/hour (OPTIMAL)
- Current grid carbon intensity (Sweden): {current_intensity:.2f} gCO2/kWh
- Instance type: t3.micro (AWS)
- Location: eu-north-1 (Stockholm, Sweden)

The '{role}' instance is operating with low carbon emissions. Provide one proactive optimization tip to maintain or further improve efficiency.

Keep the response concise (max 100 words) and technical."""
        
        # Call Amazon Bedrock
        bedrock = boto3.client('bedrock-runtime', region_name='us-east-1')
        
        # Using Claude 3 Haiku (fast and cost-effective)
        model_id = "anthropic.claude-3-haiku-20240307-v1:0"
        
        request_body = json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": 300,
            "temperature": 0.7,
            "messages": [
                {
                    "role": "user",
                    "content": prompt
                }
            ]
        })
        
        logger.info(f"Calling Bedrock model: {model_id}")
        
        response = bedrock.invoke_model(
            modelId=model_id,
            body=request_body
        )
        
        response_body = json.loads(response['body'].read())
        ai_response = response_body['content'][0]['text']
        
        logger.info("Successfully received AI insight from Bedrock")
        
        return jsonify({
            'role': role,
            'current_co2_g_hour': round(current_emissions, 2),
            'current_intensity_g_kwh': round(current_intensity, 2),
            'status': 'high' if is_high else 'optimal',
            'insight': ai_response,
            'timestamp': datetime.utcnow().isoformat() + 'Z'
        })
        
    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_msg = e.response['Error']['Message']
        logger.error(f"AWS Bedrock error ({error_code}): {error_msg}")
        
        return jsonify({
            'role': role,
            'error': f"Bedrock API error: {error_code}",
            'message': error_msg,
            'fallback_insight': f"Unable to generate AI insight. Current emissions: {current_emissions:.2f} g/hour. Consider: 1) Right-sizing instances, 2) Using spot instances, 3) Implementing auto-scaling."
        }), 500
        
    except Exception as e:
        logger.error(f"Error generating AI insight: {e}")
        return jsonify({
            'role': role,
            'error': str(e),
            'fallback_insight': "AI insight temporarily unavailable. General recommendation: Monitor and optimize resource utilization."
        }), 500


@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy', 'role': role})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
PYEOF

# Create systemd service for carbon service
cat > /etc/systemd/system/carbon-service.service <<EOF
[Unit]
Description=Carbon Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/carbon-service
Environment="PATH=/opt/carbon-service/venv/bin:/usr/local/bin:/usr/bin:/bin"
Environment="INSTANCE_ROLE=${role}"
ExecStart=/opt/carbon-service/venv/bin/python /opt/carbon-service/app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable carbon-service
systemctl start carbon-service

echo "CarbonShift setup complete for ${role}!"
echo "Node Exporter: http://localhost:9100/metrics"
echo "Carbon Service: http://localhost:8080/metrics"
echo "AI Insight: http://localhost:8080/ai-insight"
