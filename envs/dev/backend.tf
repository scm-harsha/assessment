
terraform {
  backend "s3" {
    bucket         = "tf-state"
    key            = "envs/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock-dev"
  }
}
