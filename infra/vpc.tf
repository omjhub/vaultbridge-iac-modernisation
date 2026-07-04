# ============================================================
# VaultBridge Network Infrastructure
# Three-tier network architecture:
# - Public subnets for application tier (EC2)
# - Private subnets for data tier (RDS)
# - Internet Gateway for public subnet internet access
# - No internet gateway route for private subnets (by design)
# ============================================================

# ------------------------------------------------------------
# VPC — The network container for all VaultBridge resources
# ------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "vaultbridge-vpc"
  }
}

# ------------------------------------------------------------
# Public Subnets — Application tier
# EC2 instances live here, internet accessible via IGW
# ------------------------------------------------------------

resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "vaultbridge-public-subnet-${count.index + 1}"
    Tier = "public"
  }
}

# ------------------------------------------------------------
# Private Subnets — Data tier
# RDS database lives here, NO internet access by design
# This architectural isolation is the fix for the Nov 2023
# security group misconfiguration incident
# ------------------------------------------------------------

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = false

  tags = {
    Name = "vaultbridge-private-subnet-${count.index + 1}"
    Tier = "private"
  }
}

# ------------------------------------------------------------
# Internet Gateway — Entry point from internet to public subnets
# Only public subnets have a route to this gateway
# Private subnets have no route here — database cannot be
# reached from the internet regardless of security group rules
# ------------------------------------------------------------

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "vaultbridge-igw"
  }
}

# ------------------------------------------------------------
# Public Route Table — Routes internet traffic via IGW
# Associated with public subnets only
# ------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "vaultbridge-public-rt"
  }
}

# ------------------------------------------------------------
# Route Table Associations — Links public subnets to public RT
# Private subnets get the VPC default route table which has
# no internet gateway route
# ------------------------------------------------------------

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------
# Outputs — VPC and subnet IDs needed by security group
# and compute configurations on Days 4 and 5
# ------------------------------------------------------------

output "vpc_id" {
  description = "The ID of the VaultBridge VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}