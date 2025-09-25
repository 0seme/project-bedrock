# rds-sg.tf
resource "aws_security_group" "project_rds_sg" {
  name        = "project-rds-sg"
  description = "Allow access to RDS from my IP and EKS"
  vpc_id      = "vpc-00b4f36ebfc654828"

  ingress {
    description = "My laptop"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["98.97.79.197/32"]
  }

  ingress {
    description     = "EKS cluster SG"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = ["sg-0628505355dc6aeb4"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "project-rds-sg"
  }
}
