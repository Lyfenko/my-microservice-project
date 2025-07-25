terraform {
  backend "s3" {
    bucket         = "lesson-5-tfstate-216612008115"
    key            = "lesson-5/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
