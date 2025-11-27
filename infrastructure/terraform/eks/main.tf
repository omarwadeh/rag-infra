terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = var.region
}

# Lees VPC state uit lokale state file van ../vpc
data "terraform_remote_state" "vpc" {
  backend = "local"

  config = {
    path = "../vpc/terraform.tfstate"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  # nieuwe namen in v21:
  # cluster_name   -> name
  # cluster_version -> kubernetes_version
  name               = var.cluster_name
  kubernetes_version = "1.29"

  vpc_id     = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.vpc.outputs.private_app_subnets

eks_managed_node_groups = {
  main = {
    desired_size   = 1
    min_size       = 1
    max_size       = 1
    instance_types = ["t3.small"]
    capacity_type  = "ON_DEMAND"
  }
}


  tags = {
    Project = "RAG"
    Env     = "dev"
  }
}
