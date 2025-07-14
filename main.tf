provider "aws" {
  region = "us-east-1"
}

module "s3_backend_bootstrap" {
  source = "./modules/s3-backend"
  bucket_name = "lesson-5-tfstate-216612008115"
  table_name = "terraform-locks"
}

module "vpc" {
  source              = "./modules/vpc"
  vpc_cidr_block      = "10.0.0.0/16"
  public_subnets      = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets     = ["10.0.3.0/24", "10.0.4.0/24"]
  availability_zones  = ["us-east-1a", "us-east-1b"]
  vpc_name            = "lesson7-vpc"
}

module "ecr" {
  source   = "./modules/ecr"
  ecr_name = "lesson7-django-repo"
}

module "eks" {
  source               = "./modules/eks"
  cluster_name         = "lesson7-eks"
  cluster_version      = "1.29"
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
}
