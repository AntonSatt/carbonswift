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
pip install flask requests boto3 prometheus-client psutil

# Download the carbon service application from GitHub
echo "Downloading Flask app..."
curl -sSL https://raw.githubusercontent.com/AntonSatt/carbonswift/develop/terraform/scripts/app.py -o /opt/carbon-service/app.py
chmod +x /opt/carbon-service/app.py

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
Environment="AI_AUTO_REFRESH_SECONDS=${ai_auto_refresh_seconds}"
Environment="BALANCE_WEIGHT=${balance_weight}"
ExecStart=/opt/carbon-service/venv/bin/python /opt/carbon-service/app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable carbon-service
systemctl start carbon-service

# Download dynamic workload simulator from GitHub
echo "Downloading workload simulator..."
curl -sSL https://raw.githubusercontent.com/AntonSatt/carbonswift/develop/terraform/scripts/loadgen.py -o /opt/carbon-service/loadgen.py
chmod +x /opt/carbon-service/loadgen.py

# Create systemd service for workload simulator
cat > /etc/systemd/system/workload-simulator.service <<EOF
[Unit]
Description=CarbonShift Dynamic Workload Simulator
After=network.target carbon-service.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/carbon-service
Environment="PATH=/opt/carbon-service/venv/bin:/usr/local/bin:/usr/bin:/bin"
Environment="INSTANCE_ROLE=${role}"
Environment="ENABLE_DYNAMIC_LOAD=${enable_dynamic_load}"
ExecStart=/opt/carbon-service/loadgen.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable workload-simulator
systemctl start workload-simulator

echo "CarbonShift setup complete for ${role}!"
echo "Node Exporter: http://localhost:9100/metrics"
echo "Carbon Service: http://localhost:8080/metrics"
echo "AI Insight: http://localhost:8080/ai-insight"
echo "Recommendation: http://localhost:8080/recommendation"
echo "Dynamic Workload: ${enable_dynamic_load}"
