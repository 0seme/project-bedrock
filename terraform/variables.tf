variable "account_id" {
  description = "AWS account id"
  type        = string
  default     = "562169195760"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Local AWS CLI profile to use for Terraform"
  type        = string
  default     = "default"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.0.2.0/24", "10.0.3.0/24"]
}

variable "k8s_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.32"
}
