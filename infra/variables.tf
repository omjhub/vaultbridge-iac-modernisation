# ============================================================
# VaultBridge Infrastructure — Variable Declarations
#
# IMPORTANT: This file contains declarations only — no values.
# Actual values live in terraform.tfvars which is gitignored.
#
# Validation blocks enforce business rules before any plan
# is generated. Invalid inputs are caught before any AWS API
# calls are made — the cheapest possible point to catch errors.
# ============================================================

variable "aws_region" {
  description = "The AWS region to deploy VaultBridge infrastructure into"
  type        = string
  default     = "eu-west-1"

  validation {
    condition     = contains(["eu-west-1", "eu-west-2", "af-south-1"], var.aws_region)
    error_message = "aws_region must be eu-west-1 (Ireland), eu-west-2 (London), or af-south-1 (Cape Town). These are the approved VaultBridge deployment regions."
  }
}

variable "vpc_cidr" {
  description = "The CIDR block for the VaultBridge VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block. Example: 10.0.0.0/16"
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the two public subnets — one per availability zone"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Exactly two public subnet CIDRs required — one per availability zone. RDS subnet groups require multi-AZ coverage."
  }

  validation {
    condition     = alltrue([for cidr in var.public_subnet_cidrs : can(cidrhost(cidr, 0))])
    error_message = "All public subnet CIDRs must be valid IPv4 CIDR blocks."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the two private subnets — one per availability zone"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "Exactly two private subnet CIDRs required — one per availability zone."
  }

  validation {
    condition     = alltrue([for cidr in var.private_subnet_cidrs : can(cidrhost(cidr, 0))])
    error_message = "All private subnet CIDRs must be valid IPv4 CIDR blocks."
  }
}

variable "availability_zones" {
  description = "Availability zones for subnet deployment — must match the selected region"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Exactly two availability zones required to satisfy RDS DB subnet group multi-AZ requirements."
  }
}

variable "my_ip_cidr" {
  description = "Your public IP address in /32 CIDR notation for SSH access. Format: x.x.x.x/32. A broader CIDR violates least-privilege policy."
  type        = string

  validation {
    condition     = can(cidrhost(var.my_ip_cidr, 0)) && endswith(var.my_ip_cidr, "/32")
    error_message = "my_ip_cidr must be a /32 CIDR (single host). Example: 86.131.33.253/32. A broader CIDR would open SSH to multiple hosts, violating least-privilege security policy."
  }
}

variable "db_username" {
  description = "Master username for the RDS PostgreSQL instance. Reserved names (admin, root, postgres) are not permitted."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_username) >= 4 && !contains(["admin", "root", "postgres", "administrator", "superuser"], var.db_username)
    error_message = "db_username must be at least 4 characters and cannot be a reserved PostgreSQL or AWS RDS name (admin, root, postgres, administrator, superuser)."
  }
}

variable "db_password" {
  description = "Master password for the RDS PostgreSQL instance. Minimum 12 characters per CBN credential policy requirements."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 12
    error_message = "db_password must be at least 12 characters. CBN compliance requirements mandate strong credential policies for financial services databases."
  }
}


variable "ec2_public_key" {
  description = "SSH public key for EC2 instance access. Passed via CI/CD pipeline secret or terraform.tfvars locally."
  type        = string
  sensitive   = true
}