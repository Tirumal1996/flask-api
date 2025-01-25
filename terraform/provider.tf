terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = "flask-tr-s3"
    key            = "tfstate/state"
    region         = "us-east-1"
    dynamodb_table = "trdynamodb"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Environment = "production"
      Project     = "flask-api"
    }
  }
}