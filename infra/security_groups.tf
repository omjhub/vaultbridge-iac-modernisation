# ============================================================
# VaultBridge Security Groups
# 
# Two security groups implementing least-privilege access:
# 1. EC2 security group — application tier firewall
# 2. RDS security group — database tier firewall
#
# The RDS security group references the EC2 security group
# by ID rather than by CIDR — this is the architectural fix
# for the November 2023 security group misconfiguration
# incident. Even if a CIDR-based rule were added to the RDS
# security group, the private subnet routing ensures the
# database remains unreachable from the internet.
# ============================================================

# ------------------------------------------------------------
# EC2 Security Group — Application Tier
# Controls traffic to and from the VaultBridge application
# server in the public subnet
# ------------------------------------------------------------

resource "aws_security_group" "ec2" {
  name        = "vaultbridge-ec2-sg"
  description = "Security group for VaultBridge EC2 application server"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "vaultbridge-ec2-sg"
    Tier = "application"
  }
}

# SSH access — restricted to engineer's IP only
# This implements least-privilege: only the authorised
# engineer can administer the server remotely
resource "aws_vpc_security_group_ingress_rule" "ec2_ssh" {
  security_group_id = aws_security_group.ec2.id
  description       = "SSH access from authorised engineer IP only"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = var.my_ip_cidr
}

# HTTP access — open to all internet traffic
# The application must be reachable by VaultBridge's users
# across Nigeria, Kenya, Ghana, and Rwanda
resource "aws_vpc_security_group_ingress_rule" "ec2_http" {
  security_group_id = aws_security_group.ec2.id
  description       = "HTTP access from internet for VaultBridge application users"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# All outbound traffic permitted
# Required for: database connections, external API calls,
# software updates, AWS service communication
resource "aws_vpc_security_group_egress_rule" "ec2_all_outbound" {
  security_group_id = aws_security_group.ec2.id
  description       = "Allow all outbound traffic from EC2 instance"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ------------------------------------------------------------
# RDS Security Group — Database Tier
# Controls traffic to and from the VaultBridge PostgreSQL
# database in the private subnet
# ------------------------------------------------------------

resource "aws_security_group" "rds" {
  name        = "vaultbridge-rds-sg"
  description = "Security group for VaultBridge RDS PostgreSQL database"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "vaultbridge-rds-sg"
    Tier = "database"
  }
}

# PostgreSQL access — from EC2 security group ONLY
# This is the critical rule. Port 5432 is accepted ONLY from
# resources that have the EC2 security group attached.
# No CIDR range. No open access. Application tier only.
# This is the architectural fix for the November 2023 incident.
resource "aws_vpc_security_group_ingress_rule" "rds_postgres" {
  security_group_id            = aws_security_group.rds.id
  description                  = "PostgreSQL access from EC2 application tier only"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ec2.id
}

# Outbound — allow responses back to EC2
resource "aws_vpc_security_group_egress_rule" "rds_outbound" {
  security_group_id = aws_security_group.rds.id
  description       = "Allow outbound traffic from RDS"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ------------------------------------------------------------
# Outputs — Security group IDs needed by EC2 and RDS
# configurations on Day 5
# ------------------------------------------------------------

output "ec2_security_group_id" {
  description = "ID of the EC2 security group"
  value       = aws_security_group.ec2.id
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds.id
}