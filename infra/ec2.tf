# ============================================================
# VaultBridge EC2 Application Server
#
# Components:
# 1. AMI data source — always finds latest Amazon Linux 2023
# 2. Key pair — SSH authentication using local public key
# 3. EC2 instance — t3.micro in public subnet with encryption
# 4. Elastic IP — permanent public IP surviving restarts
#
# Placed in public subnet to receive application traffic.
# Security group restricts SSH to authorised IP only.
# RDS in private subnet is unreachable from this instance's
# public subnet position — only via private VPC routing.
# ============================================================

# ------------------------------------------------------------
# Data Source — Latest Amazon Linux 2023 AMI
# Queries AWS AMI catalogue at apply time — always current
# ------------------------------------------------------------

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# ------------------------------------------------------------
# Key Pair — SSH Authentication
# References local public key — private key never leaves
# your machine, never touches AWS
# ------------------------------------------------------------

resource "aws_key_pair" "vaultbridge" {
  key_name   = "vaultbridge-key"
  public_key = file("~/.ssh/id_ed25519.pub")

  tags = {
    Name = "vaultbridge-key"
  }
}

# ------------------------------------------------------------
# EC2 Instance — VaultBridge Application Server
# ------------------------------------------------------------

resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = aws_key_pair.vaultbridge.key_name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y postgresql15
  EOF

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "vaultbridge-app-server-root"
    }
  }

  # ── Lifecycle Controls ──────────────────────────────────────
  # ignore_changes on ami:
  #   Prevents automatic instance replacement when AWS releases
  #   a newer Amazon Linux 2023 AMI. Without this, every new AMI
  #   release causes terraform plan to show an instance replacement.
  #   AMI updates should be deliberate decisions via a planned
  #   patching cycle — not automatic consequences of a data source.
  #
  # ignore_changes on user_data:
  #   Prevents replacement if user_data content is updated.
  #   user_data only runs on first boot, so changing it without
  #   this block would destroy and recreate the instance.
  lifecycle {
    ignore_changes = [ami, user_data]
  }

  tags = {
    Name = "vaultbridge-app-server"
    Role = "application"
  }
}

# ------------------------------------------------------------
# Elastic IP — Permanent Public IP Address
# Survives instance stop/start and replacement
# Critical for VaultBridge's 99.95% uptime SLA
# ------------------------------------------------------------

resource "aws_eip" "app_server" {
  instance = aws_instance.app_server.id
  domain   = "vpc"

  tags = {
    Name = "vaultbridge-app-server-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

# ------------------------------------------------------------
# Outputs — Values needed for SSH access and Day 2 RDS config
# ------------------------------------------------------------

output "ec2_public_ip" {
  description = "The Elastic IP address of the VaultBridge application server"
  value       = aws_eip.app_server.public_ip
}

output "ec2_instance_id" {
  description = "The instance ID of the VaultBridge application server"
  value       = aws_instance.app_server.id
}

output "ami_id_used" {
  description = "The AMI ID used to launch the instance"
  value       = data.aws_ami.amazon_linux_2023.id
}