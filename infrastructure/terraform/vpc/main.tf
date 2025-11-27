terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # versie laat je door Terraform kiezen
    }
  }
}

provider "aws" {
  region = var.region
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.5.0"

  name = var.name
  cidr = var.cidr

  azs              = var.azs
  public_subnets   = ["10.10.0.0/20", "10.10.16.0/20", "10.10.32.0/20"]
  private_subnets  = ["10.10.48.0/20", "10.10.64.0/20", "10.10.80.0/20"]
  database_subnets = ["10.10.96.0/24", "10.10.97.0/24", "10.10.98.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = var.single_nat_gateway
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = {
    Project = "RAG"
    Env     = "dev"
  }
}
