# ============================================================
# Variable Declarations
# This file declares variables only — no values here
# Actual values live in terraform.tfvars (gitignored)
# ============================================================

variable "aws_region" {
  description = "The AWS region to deploy VaultBridge infrastructure into"
  type        = string
  default     = "eu-west-1"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VaultBridge VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets across two availability zones"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets across two availability zones"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "availability_zones" {
  description = "Availability zones to deploy subnets into"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
}

variable "my_ip_cidr" {
  description = "Your public IP address in CIDR notation for SSH access to EC2. Format: x.x.x.x/32"
  type        = string
}

variable "db_username" {
  description = "Master username for the RDS PostgreSQL instance"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Master password for the RDS PostgreSQL instance. Must be at least 8 characters."
  type        = string
  sensitive   = true
}