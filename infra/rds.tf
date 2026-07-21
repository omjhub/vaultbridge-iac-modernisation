# ============================================================
# VaultBridge RDS PostgreSQL Database
#
# Three-layer security model:
# 1. Private subnet — no internet gateway route (architectural)
# 2. RDS security group — port 5432 from EC2 SG only (network)
# 3. publicly_accessible = false — no public DNS endpoint (RDS)
#
# All three must fail simultaneously for the database to be
# internet-exposed. This is the architectural fix for the
# November 2023 security group misconfiguration incident.
# ============================================================

# ------------------------------------------------------------
# DB Subnet Group — Defines which subnets RDS can use
# Must span at least two availability zones
# Both subnets are private — no internet gateway route
# ------------------------------------------------------------

resource "aws_db_subnet_group" "vaultbridge" {
  name        = "vaultbridge-db-subnet-group"
  description = "Private subnet group for VaultBridge RDS PostgreSQL database"
  subnet_ids  = aws_subnet.private[*].id

  tags = {
    Name = "vaultbridge-db-subnet-group"
  }
}

# ------------------------------------------------------------
# DB Parameter Group — PostgreSQL 15 configuration
# Enables connection logging for CBN audit compliance
# ------------------------------------------------------------

resource "aws_db_parameter_group" "vaultbridge" {
  name        = "vaultbridge-postgres15-params"
  family      = "postgres15"
  description = "VaultBridge PostgreSQL 15 parameter group with audit logging"

  parameter {
    name         = "log_connections"
    value        = "1"
    apply_method = "immediate"
  }

  parameter {
    name         = "log_disconnections"
    value        = "1"
    apply_method = "immediate"
  }

  parameter {
    name         = "log_duration"
    value        = "1"
    apply_method = "immediate"
  }

  tags = {
    Name = "vaultbridge-postgres15-params"
  }
}

# ------------------------------------------------------------
# RDS Instance — VaultBridge PostgreSQL 15 Database
#
# Security controls applied:
# - Placed in private subnet group (no internet route)
# - RDS security group limits access to EC2 tier only
# - publicly_accessible = false (no public DNS endpoint)
# - storage_encrypted = true (AES-256 at rest)
# - Credentials sourced from variables (never hardcoded)
# ------------------------------------------------------------

resource "aws_db_instance" "vaultbridge" {
  identifier = "vaultbridge-postgres"

  # Engine configuration
  engine         = "postgres"
  engine_version = "15.18"
  instance_class = "db.t3.micro"
  auto_minor_version_upgrade = true  # AWS applies PostgreSQL security patches automatically

  # Storage configuration
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  # Database credentials — sourced from variables, never hardcoded
  db_name  = "vaultbridge"
  username = var.db_username
  password = var.db_password

  # Network configuration — three-layer security
  db_subnet_group_name   = aws_db_subnet_group.vaultbridge.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # Parameter group — enables audit logging
  parameter_group_name = aws_db_parameter_group.vaultbridge.name

  # Backup configuration
  backup_retention_period = 0
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # For this learning exercise only — skip final snapshot on destroy
  # In production this must be false
  skip_final_snapshot = true
  deletion_protection = false

  # ── Lifecycle Controls ──────────────────────────────────────
  # prevent_destroy:
  #   Prevents accidental destruction of the database through
  #   terraform destroy or removal of this resource block.
  #   The RDS database contains VaultBridge financial transaction
  #   records. Accidental deletion is an existential business risk.
  #
  #   To intentionally destroy this resource:
  #   1. Set prevent_destroy = true → false
  #   2. Run terraform apply to register the change
  #   3. Then run terraform destroy
  #
  #   LEARNING ENVIRONMENT NOTE: Set to false here so the
  #   project can be cleanly torn down after the programme.
  #   In production this MUST be true.
  lifecycle {
    prevent_destroy = false # Change to true in production
  }

  tags = {
    Name = "vaultbridge-postgres"
    Tier = "database"
  }
}

# ------------------------------------------------------------
# Outputs — RDS endpoint needed for EC2 connectivity test
# ------------------------------------------------------------

output "rds_endpoint" {
  description = "The connection endpoint for the VaultBridge RDS database"
  value       = aws_db_instance.vaultbridge.endpoint
}

output "rds_port" {
  description = "The port the RDS database listens on"
  value       = aws_db_instance.vaultbridge.port
}

output "rds_database_name" {
  description = "The name of the initial database"
  value       = aws_db_instance.vaultbridge.db_name
}