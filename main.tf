provider "aws" {
  region = "us-east-1"
}

module "s3_backend_bootstrap" {
  source = "./modules/s3-backend"
  bucket_name = "lesson-5-tfstate-216612008115"
  table_name = "terraform-locks"
}
