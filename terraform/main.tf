terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source for latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Data source for default VPC
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group
resource "aws_security_group" "carbon_shift" {
  name        = "carbon-shift-sg"
  description = "Security group for CarbonShift instances"
  vpc_id      = data.aws_vpc.default.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # Node Exporter
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Node Exporter metrics"
  }

  # Carbon Service
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Carbon Service API"
  }

  # Grafana Alloy
  ingress {
    from_port   = 12345
    to_port     = 12345
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Grafana Alloy"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name    = "carbon-shift-sg"
    Project = "CarbonShift"
  }
}

# EC2 Instances
resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.carbon_shift.name
  vpc_security_group_ids = [aws_security_group.carbon_shift.id]
  user_data              = templatefile("${path.module}/user_data.sh", {
    role               = "web-server"
    grafana_cloud_url  = var.grafana_cloud_prometheus_url
    grafana_cloud_user = var.grafana_cloud_prometheus_user
    grafana_cloud_key  = var.grafana_cloud_api_key
  })

  tags = {
    Name    = "carbon-shift-web-server"
    Role    = "web-server"
    Project = "CarbonShift"
  }
}

resource "aws_instance" "api_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.carbon_shift.name
  vpc_security_group_ids = [aws_security_group.carbon_shift.id]
  user_data              = templatefile("${path.module}/user_data.sh", {
    role               = "api-server"
    grafana_cloud_url  = var.grafana_cloud_prometheus_url
    grafana_cloud_user = var.grafana_cloud_prometheus_user
    grafana_cloud_key  = var.grafana_cloud_api_key
  })

  tags = {
    Name    = "carbon-shift-api-server"
    Role    = "api-server"
    Project = "CarbonShift"
  }
}

resource "aws_instance" "compute_worker" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.carbon_shift.name
  vpc_security_group_ids = [aws_security_group.carbon_shift.id]
  user_data              = templatefile("${path.module}/user_data.sh", {
    role               = "compute-worker"
    grafana_cloud_url  = var.grafana_cloud_prometheus_url
    grafana_cloud_user = var.grafana_cloud_prometheus_user
    grafana_cloud_key  = var.grafana_cloud_api_key
  })

  tags = {
    Name    = "carbon-shift-compute-worker"
    Role    = "compute-worker"
    Project = "CarbonShift"
  }
}
