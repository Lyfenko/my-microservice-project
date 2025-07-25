# Спільні ресурси для обох типів БД
resource "aws_db_subnet_group" "default" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids
  tags       = merge(var.tags, { Name = "${var.identifier}-subnet-group" })
}

resource "aws_security_group" "db" {
  name        = "${var.identifier}-sg"
  description = "Security group for ${var.identifier}"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.identifier}-sg" })

  ingress {
    from_port   = var.port
    to_port     = var.port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_parameter_group" "default" {
  name        = "${var.identifier}-param-group"
  family      = var.parameter_group_family
  description = "Parameter group for ${var.identifier}"
  tags        = merge(var.tags, { Name = "${var.identifier}-param-group" })

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      # Використовуємо pending-reboot для статичних параметрів
      apply_method = contains(["max_connections", "shared_buffers"], parameter.value.name) ? "pending-reboot" : "immediate"
    }
  }
}