variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "eu-north-1" # Sweden
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "grafana_cloud_prometheus_url" {
  description = "Grafana Cloud Prometheus remote write URL"
  type        = string
  sensitive   = true
}

variable "grafana_cloud_prometheus_user" {
  description = "Grafana Cloud Prometheus username/instance ID"
  type        = string
  sensitive   = true
}

variable "grafana_cloud_api_key" {
  description = "Grafana Cloud API key for Prometheus"
  type        = string
  sensitive   = true
}

variable "ssh_key_name" {
  description = "Name of the SSH key pair to use for EC2 instances (optional)"
  type        = string
  default     = ""
}
