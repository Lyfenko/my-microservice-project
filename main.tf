terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.3"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

module "s3_backend_bootstrap" {
  source      = "./modules/s3-backend"
  bucket_name = "lesson-5-tfstate-216612008115"
  table_name  = "terraform-locks"
}

module "vpc" {
  source             = "./modules/vpc"
  vpc_cidr_block     = "10.0.0.0/16"
  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets    = ["10.0.3.0/24", "10.0.4.0/24"]
  availability_zones = ["us-east-1a", "us-east-1b"]
  vpc_name           = "lesson7-vpc"
}

module "ecr" {
  source   = "./modules/ecr"
  ecr_name = "lesson7-django-repo"
}

module "eks" {
  source             = "./modules/eks"
  cluster_name       = "lesson7-eks"
  cluster_version    = "1.29"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
}

module "jenkins" {
  source              = "./modules/jenkins"
  eks_cluster_endpoint = module.eks.cluster_endpoint
}

module "argocd" {
  source              = "./modules/argocd"
  eks_cluster_endpoint = module.eks.cluster_endpoint
}

module "rds" {
  source = "./modules/rds"

  use_aurora  = false # Set to true for Aurora
  identifier  = "prod-db"
  engine      = "postgres"
  db_name     = var.db_name
  username    = var.db_user
  password    = var.db_password
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnet_ids
  allowed_cidr_blocks = [module.vpc.vpc_cidr_block]

  parameters = [
    {
      name  = "max_connections"
      value = "200"
    },
    {
      name  = "log_statement"
      value = "ddl"
    }
  ]

  tags = {
    Environment = "production"
    Project     = "my-microservice"
  }
}

# Додати нові змінні
variable "db_name" {
  type = string
}

variable "db_user" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}