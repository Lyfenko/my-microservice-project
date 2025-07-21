output "endpoint" {
  description = "DB connection endpoint"
  value = var.use_aurora ? aws_rds_cluster.aurora[0].endpoint : aws_db_instance.default[0].endpoint
}

output "port" {
  description = "Database port"
  value       = var.port
}

output "db_name" {
  description = "Database name"
  value       = var.db_name
}

output "username" {
  description = "Master username"
  value       = var.username
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.db.id
}

output "parameter_group_name" {
  description = "Parameter group name"
  value       = aws_db_parameter_group.default.name
}

output "subnet_group_name" {
  description = "Subnet group name"
  value       = aws_db_subnet_group.default.name
}

output "writer_instance_endpoint" {
  description = "Writer instance endpoint (Aurora only)"
  value       = var.use_aurora ? aws_rds_cluster_instance.writer[0].endpoint : null
}