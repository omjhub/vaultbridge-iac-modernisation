# ============================================================
# VaultBridge Infrastructure Outputs
# Consolidated reference values for all infrastructure layers
# These values are stored in remote state and available to
# other workspaces, CI/CD pipelines, and documentation
# ============================================================

# ------------------------------------------------------------
# Network Layer — Day 3
# ------------------------------------------------------------

output "vpc_id_summary" {
  description = "VaultBridge VPC ID"
  value       = aws_vpc.main.id
}

# ------------------------------------------------------------
# Compute Layer — Week 2 Day 1
# ------------------------------------------------------------

output "app_server_public_ip" {
  description = "Elastic IP of the VaultBridge application server"
  value       = aws_eip.app_server.public_ip
}

output "app_server_instance_id" {
  description = "Instance ID of the VaultBridge application server"
  value       = aws_instance.app_server.id
}

# ------------------------------------------------------------
# Database Layer — Week 2 Day 2
# Connection string components for application configuration
# ------------------------------------------------------------

output "database_endpoint" {
  description = "RDS endpoint for application database connection"
  value       = aws_db_instance.vaultbridge.endpoint
}

output "database_port" {
  description = "RDS port"
  value       = aws_db_instance.vaultbridge.port
}

output "database_name" {
  description = "Initial database name"
  value       = aws_db_instance.vaultbridge.db_name
}

# ------------------------------------------------------------
# SSH Connection Helper
# ------------------------------------------------------------

output "ssh_connection_command" {
  description = "Command to SSH into the VaultBridge application server"
  value       = "ssh -i ~/.ssh/id_ed25519 ec2-user@${aws_eip.app_server.public_ip}"
}

# ------------------------------------------------------------
# psql Connection Helper — for Day 2 connectivity test
# Run this from inside the EC2 instance
# ------------------------------------------------------------

output "psql_connection_command" {
  description = "Command to connect to RDS from EC2 instance (run from inside EC2)"
  value       = "psql -h ${aws_db_instance.vaultbridge.address} -U ${var.db_username} -d vaultbridge"
  sensitive   = true
}