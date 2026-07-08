# ============================================================
# VaultBridge Infrastructure Modernisation Programme
# Remote Backend Configuration
# Connects this workspace to the S3 state bucket created
# in the bootstrap workspace on Day 2
# Updated to use native S3 locking (Terraform v1.10+)
# ============================================================

terraform {
  backend "s3" {
    bucket  = "vaultbridge-terraform-state-301a163d"
    key     = "envs/dev/terraform.tfstate"
    region  = "eu-west-1"
    encrypt = true
    # dynamodb_table = "vaultbridge-terraform-locks"
    use_lockfile = true
  }
}