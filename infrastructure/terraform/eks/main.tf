terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # Belangrijk: alleen provider 5.x gebruiken (6.x gaf die elastic_* errors)
      version = ">= 5.0.0, < 6.0.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# VPC state uit ../vpc (bestaat nu, want je hebt net apply gedaan)
data "terraform_remote_state" "vpc" {
  backend = "local"

  config = {
    path = "../vpc/terraform.tfstate"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.24.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.29"

  vpc_id     = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.vpc.outputs.private_app_subnets

create_kms_key = false
cluster_encryption_config  = []

create_cloudwatch_log_group = false
cluster_enabled_log_types   = []



cluster_endpoint_public_access          = true
cluster_endpoint_private_access         = true
cluster_endpoint_public_access_cidrs    = ["0.0.0.0/0"]

enable_cluster_creator_admin_permissions = true

eks_managed_node_groups = {}


  fargate_profiles = {
    default = {
      name = "fp-default"

      selectors = [
        {
          namespace = "default"
        }
      ]

      subnet_ids = data.terraform_remote_state.vpc.outputs.private_app_subnets
    }
  }

  tags = {
    Project = "RAG"
    Env     = "dev"
  }
}
