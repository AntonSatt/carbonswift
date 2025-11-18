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

variable "enable_dynamic_load" {
  description = "Enable dynamic CPU workload simulator (role-aware, sinusoidal + bursts)"
  type        = bool
  default     = true
}

variable "ai_auto_refresh_seconds" {
  description = "How often to auto-refresh AI insight and recommendations (min 60s)"
  type        = number
  default     = 300
  validation {
    condition     = var.ai_auto_refresh_seconds >= 60
    error_message = "AI refresh interval must be at least 60 seconds"
  }
}

variable "balance_weight" {
  description = "Weight for carbon in balanced scoring (0..1). Price weight = 1 - balance_weight"
  type        = number
  default     = 0.5
  validation {
    condition     = var.balance_weight >= 0 && var.balance_weight <= 1
    error_message = "Balance weight must be between 0 and 1"
  }
}
