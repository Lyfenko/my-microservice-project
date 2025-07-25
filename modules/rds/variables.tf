variable "use_aurora" {
  type        = bool
  description = "Create Aurora Cluster (true) or regular RDS instance (false)"
  default     = false
}

variable "identifier" {
  type        = string
  description = "Unique identifier for the DB resource"
}

variable "engine" {
  type        = string
  description = "Database engine type"
  default     = "postgres"
}

variable "engine_version" {
  type        = string
  description = "Database engine version"
  default     = "15.7"
}

variable "instance_class" {
  type        = string
  description = "DB instance class"
  default     = "db.t3.micro"
}

variable "multi_az" {
  type        = bool
  description = "Enable multi-AZ deployment"
  default     = false
}

variable "db_name" {
  type        = string
  description = "Database name"
  default     = "mydb"
}

variable "username" {
  type        = string
  description = "Master username"
  default     = "admin"
}

variable "password" {
  type        = string
  description = "Master password"
  sensitive   = true
}

variable "port" {
  type        = number
  description = "Database port"
  default     = 5432
}

variable "allocated_storage" {
  type        = number
  description = "Allocated storage in GB (for RDS only)"
  default     = 20
}

variable "storage_type" {
  type        = string
  description = "Storage type (for RDS only)"
  default     = "gp2"
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Skip final snapshot when destroying DB"
  default     = true
}

variable "backup_retention_period" {
  type        = number
  description = "Backup retention period in days"
  default     = 7
}

variable "apply_immediately" {
  type        = bool
  description = "Apply changes immediately"
  default     = false
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs"
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "List of allowed CIDR blocks"
  default     = []
}

variable "parameter_group_family" {
  type        = string
  description = "DB parameter group family"
  default     = "postgres15"
}

variable "parameters" {
  type = list(object({
    name  = string
    value = string
  }))
  description = "List of DB parameters"
  default = [
    {
      name  = "max_connections"
      value = "100"
    },
    {
      name  = "log_statement"
      value = "all"
    },
    {
      name  = "work_mem"
      value = "4MB"
    }
  ]
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}