terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.13.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ---------------------------
# VPC Module
# ---------------------------

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.0.1"

  name = "project-bedrock-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  # Enable DNS support (required for EKS)
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Explicitly enable public IP mapping for public subnets (just in case)
  map_public_ip_on_launch = true

  # Tags for EKS
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  # Tag all subnets for EKS cluster discovery
  tags = {
    "kubernetes.io/cluster/project-bedrock-eks" = "shared"
  }
}

# ---------------------------
# EKS Module
# ---------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.3.1"

  name               = "project-bedrock-eks"
  kubernetes_version = "1.32"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    default = {
      desired_size   = 1
      max_size       = 2
      min_size       = 1
      instance_types = ["t3.medium"]
    }
  }
}

# Ensure cluster endpoint is publicly accessible
resource "null_resource" "update_cluster_endpoint" {
  depends_on = [module.eks]

  provisioner "local-exec" {
    command = "aws eks update-cluster-config --name project-bedrock-eks --resources-vpc-config endpointPublicAccess=true,endpointPrivateAccess=true --region us-east-1 && sleep 180"
  }

  triggers = {
    always_run = timestamp()
  }
}

# ---------------------------
# DynamoDB Table for Terraform Locks
# ---------------------------
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "project-bedrock-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Environment = "dev"
    Project     = "project-bedrock"
  }
}

# ---------------------------
# Security Group for ALB
# ---------------------------
resource "aws_security_group" "alb_sg" {
  name        = "project-bedrock-alb-sg"
  description = "Security group for ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "project-bedrock-alb-sg"
  }
}

# ---------------------------
# SSL Certificate for HTTPS
# ---------------------------

# Create a private key
resource "tls_private_key" "alb_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create a self-signed certificate
resource "tls_self_signed_cert" "alb_cert" {
  private_key_pem = tls_private_key.alb_key.private_key_pem

  subject {
    common_name  = "*.elb.amazonaws.com"
    organization = "Project Bedrock"
  }

  validity_period_hours = 8760  # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# Import the certificate to ACM
resource "aws_acm_certificate" "alb_cert" {
  private_key      = tls_private_key.alb_key.private_key_pem
  certificate_body = tls_self_signed_cert.alb_cert.cert_pem

  tags = {
    Name = "project-bedrock-alb-cert"
  }
}

# ---------------------------
# RDS MySQL Database
# ---------------------------

# Security group for RDS
resource "aws_security_group" "rds_sg" {
  name        = "project-bedrock-rds-sg"
  description = "Security group for RDS MySQL"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "MySQL from EKS nodes"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "project-bedrock-rds-sg"
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "project-bedrock-rds-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "project-bedrock-rds-subnet-group"
  }
}

# RDS MySQL Instance
resource "aws_db_instance" "project_rds" {
  identifier           = "project-rds"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  storage_type         = "gp2"
  
  db_name  = "catalogdb"
  username = "mydbuser"
  password = "SuperSecret123!"
  
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  
  publicly_accessible = false
  skip_final_snapshot = true
  
  tags = {
    Name = "project-bedrock-rds"
  }
}

# Allow ALB to communicate with EKS nodes
resource "aws_security_group_rule" "alb_to_nodes" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = module.eks.node_security_group_id
  source_security_group_id = aws_security_group.alb_sg.id
  description              = "Allow ALB to reach pods"
}

# ---------------------------
# Outputs
# ---------------------------
output "alb_security_group_id" {
  value = aws_security_group.alb_sg.id
}

output "certificate_arn" {
  value       = aws_acm_certificate.alb_cert.arn
  description = "ARN of the SSL certificate for HTTPS"
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "rds_endpoint" {
  value = aws_db_instance.project_rds.endpoint
}