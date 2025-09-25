# rds-subnet-group.tf
resource "aws_db_subnet_group" "project_rds_subnet_group" {
  name       = "project-rds-subnet-group"
  subnet_ids = [
    "subnet-081cbf4c3f9827702",
    "subnet-0caacdf2175a5c710",
    "subnet-004e0fbdbc06a7219",
  ]

  tags = {
    Name = "project-rds-subnet-group"
  }
}
