# ============================================================
# Provider Configuration
# Declares the AWS provider version constraints and
# region configuration for the infra workspace
# ============================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "VaultBridge Infrastructure Modernisation"
      Environment = "dev"
      ManagedBy   = "Terraform"
      Owner       = "VaultBridge Engineering"
    }
  }
}