# rds-instance.tf
resource "aws_db_instance" "project_rds" {
  identifier              = "project-rds"
  allocated_storage       = 20
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  username                = "mydbuser"
  password                = "***REMOVED***"
  db_subnet_group_name    = aws_db_subnet_group.project_rds_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.project_rds_sg.id]
  skip_final_snapshot     = true
  publicly_accessible     = false
  multi_az                = false
  storage_encrypted       = true
  deletion_protection     = false
}
