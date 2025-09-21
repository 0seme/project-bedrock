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

  eks_managed_node_groups = {
    default = {
      desired_size   = 1
      max_size       = 2
      min_size       = 1
      instance_types = ["t3.medium"]
    }
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