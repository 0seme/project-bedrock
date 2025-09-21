terraform {
  backend "s3" {
    bucket  = "project-bedrock-terraform-state-562169195760-us-east-1"
    key     = "project-bedrock/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

