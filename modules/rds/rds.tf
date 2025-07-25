# Ресурси для звичайної RDS
resource "aws_db_instance" "default" {
  count = var.use_aurora ? 0 : 1

  identifier           = var.identifier
  engine               = var.engine
  engine_version       = var.engine_version
  instance_class       = var.instance_class
  allocated_storage    = var.allocated_storage
  storage_type         = var.storage_type
  db_name              = var.db_name
  username             = var.username
  password             = var.password
  port                 = var.port
  multi_az             = var.multi_az
  skip_final_snapshot  = var.skip_final_snapshot
  backup_retention_period = var.backup_retention_period
  apply_immediately    = var.apply_immediately

  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.db.id]
  parameter_group_name   = aws_db_parameter_group.default.name

  publicly_accessible = false
  tags = var.tags
}