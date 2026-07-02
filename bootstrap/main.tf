# ============================================================
# VaultBridge Infrastructure Modernisation Programme
# Bootstrap Workspace
# Purpose: Create S3 bucket and DynamoDB table for remote state
# This workspace runs ONCE with local state
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
  region = "eu-west-1"
}

# ============================================================
# S3 Bucket — Remote State Storage
# ============================================================

resource "aws_s3_bucket" "terraform_state" {
  bucket = "vaultbridge-terraform-state-${random_id.suffix.hex}"

  tags = {
    Name        = "VaultBridge Terraform State"
    Environment = "bootstrap"
    Project     = "Infrastructure Modernisation Programme"
    ManagedBy   = "Terraform"
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================================
# DynamoDB Table — State Locking
# ============================================================

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "vaultbridge-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "VaultBridge Terraform State Locks"
    Environment = "bootstrap"
    Project     = "Infrastructure Modernisation Programme"
    ManagedBy   = "Terraform"
  }
}

# ============================================================
# Outputs — Values needed for Day 3 backend configuration
# ============================================================

output "state_bucket_name" {
  description = "The name of the S3 bucket storing Terraform state"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "dynamodb_table_name" {
  description = "The name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}