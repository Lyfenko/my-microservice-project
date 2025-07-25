# Ресурси для Aurora Cluster
resource "aws_rds_cluster" "aurora" {
  count = var.use_aurora ? 1 : 0

  cluster_identifier      = var.identifier
  engine                  = var.engine
  engine_version          = var.engine_version
  database_name           = var.db_name
  master_username         = var.username
  master_password         = var.password
  port                    = var.port
  skip_final_snapshot     = var.skip_final_snapshot
  backup_retention_period = var.backup_retention_period
  storage_encrypted       = true
  apply_immediately       = var.apply_immediately

  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.db.id]
  db_cluster_parameter_group_name = aws_db_parameter_group.default.name

  tags = var.tags
}

resource "aws_rds_cluster_instance" "writer" {
  count = var.use_aurora ? 1 : 0

  identifier         = "${var.identifier}-writer"
  cluster_identifier = aws_rds_cluster.aurora[0].id
  instance_class     = var.instance_class
  engine             = var.engine
  engine_version     = var.engine_version
  publicly_accessible = false

  db_parameter_group_name = aws_db_parameter_group.default.name
  tags = var.tags
}