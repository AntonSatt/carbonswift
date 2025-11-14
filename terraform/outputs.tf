output "web_server_public_ip" {
  description = "Public IP address of the web-server instance"
  value       = aws_instance.web_server.public_ip
}

output "api_server_public_ip" {
  description = "Public IP address of the api-server instance"
  value       = aws_instance.api_server.public_ip
}

output "compute_worker_public_ip" {
  description = "Public IP address of the compute-worker instance"
  value       = aws_instance.compute_worker.public_ip
}

output "web_server_instance_id" {
  description = "Instance ID of the web-server"
  value       = aws_instance.web_server.id
}

output "api_server_instance_id" {
  description = "Instance ID of the api-server"
  value       = aws_instance.api_server.id
}

output "compute_worker_instance_id" {
  description = "Instance ID of the compute-worker"
  value       = aws_instance.compute_worker.id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.carbon_shift.id
}

output "iam_role_arn" {
  description = "ARN of the IAM role with Bedrock permissions"
  value       = aws_iam_role.carbon_shift.arn
}

output "carbon_service_endpoints" {
  description = "Carbon service endpoints for each instance"
  value = {
    web_server = {
      metrics    = "http://${aws_instance.web_server.public_ip}:8080/metrics"
      ai_insight = "http://${aws_instance.web_server.public_ip}:8080/ai-insight"
    }
    api_server = {
      metrics    = "http://${aws_instance.api_server.public_ip}:8080/metrics"
      ai_insight = "http://${aws_instance.api_server.public_ip}:8080/ai-insight"
    }
    compute_worker = {
      metrics    = "http://${aws_instance.compute_worker.public_ip}:8080/metrics"
      ai_insight = "http://${aws_instance.compute_worker.public_ip}:8080/ai-insight"
    }
  }
}

output "node_exporter_endpoints" {
  description = "Node Exporter metrics endpoints"
  value = {
    web_server     = "http://${aws_instance.web_server.public_ip}:9100/metrics"
    api_server     = "http://${aws_instance.api_server.public_ip}:9100/metrics"
    compute_worker = "http://${aws_instance.compute_worker.public_ip}:9100/metrics"
  }
}
