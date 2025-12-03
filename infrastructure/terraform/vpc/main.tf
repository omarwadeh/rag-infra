terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # GEEN version hier -> module kiest zelf
    }
  }
}

provider "aws" {
  region = var.region
}


module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.name
  cidr = var.cidr
  azs  = var.azs

  # PRIVATE app subnets (EKS nodes)
  private_subnets = [
    "192.168.1.0/24",
    "192.168.2.0/24",
  ]

  # DATA subnets
  database_subnets = [
    "192.168.101.0/24",
    "192.168.102.0/24",
  ]

  create_database_subnet_group = false

  # KLEINE PUBLIC SUBNETS, ALLEEN VOOR NAT/IGW
  public_subnets = [
    "192.168.10.0/24",
    "192.168.20.0/24",
  ]

  create_igw = true

  # NAT AAN (nodes kunnen naar buiten, maar blijven privé)
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_dns_support   = true
  enable_dns_hostnames = true

  # Flow logs uit
  enable_flow_log = false

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

