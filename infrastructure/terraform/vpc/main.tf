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

  # 
  # expliciet als resources aanmaken (routes via IGW/NAT).
  create_igw = false

  # NAT uit in module; we maken hieronder zelf 1 NAT Gateway aan.
  enable_nat_gateway     = false
  single_nat_gateway     = false
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


# 1) Internet Gateway (IGW)

resource "aws_internet_gateway" "this" {
  vpc_id = module.vpc.vpc_id

  tags = {
    Name    = "${var.name}-igw"
    Project = "RAG"
    Env     = "dev"
  }
}

# 2) NAT Gateway (in public subnet) + EIP

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name    = "${var.name}-nat-eip"
    Project = "RAG"
    Env     = "dev"
  }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = module.vpc.public_subnets[0]

  # Zorgt dat de IGW er eerst is (AWS best practice voor public egress).
  depends_on = [aws_internet_gateway.this]

  tags = {
    Name    = "${var.name}-nat"
    Project = "RAG"
    Env     = "dev"
  }
}

# 3) Routing table rules voor internet access
#    - Public subnets: 0.0.0.0/0 -> IGW
#    - Private subnets: 0.0.0.0/0 -> NAT

resource "aws_route" "public_internet_access" {
  count                  = length(module.vpc.public_route_table_ids)
  route_table_id         = module.vpc.public_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route" "private_outbound_via_nat" {
  count                  = length(module.vpc.private_route_table_ids)
  route_table_id         = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}



# 4) Security Group rule: internet -> API (public)

resource "aws_security_group" "api_public" {
  name        = "${var.name}-api-public"
  description = "Allow inbound internet traffic to API (public)"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name    = "${var.name}-api-public"
    Project = "RAG"
    Env     = "dev"
  }
}

resource "aws_vpc_security_group_ingress_rule" "api_from_internet" {
  security_group_id = aws_security_group.api_public.id
  description       = "Internet_to_API_8000" # <-- FIX (geen ->)
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = var.api_port
  to_port           = var.api_port
  ip_protocol       = "tcp"
}


resource "aws_vpc_security_group_egress_rule" "api_all_outbound" {
  security_group_id = aws_security_group.api_public.id
  description       = "Allow all outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "api_private" {
  name        = "${var.name}-api-private"
  description = "Allow API traffic from public SG to private workloads"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name    = "${var.name}-api-private"
    Project = "RAG"
    Env     = "dev"
  }
}

resource "aws_vpc_security_group_ingress_rule" "private_from_public_api" {
  security_group_id            = aws_security_group.api_private.id
  description                  = "Public_API_to_Private_8000"
  referenced_security_group_id = aws_security_group.api_public.id
  from_port                    = var.api_port
  to_port                      = var.api_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "private_all_outbound" {
  security_group_id = aws_security_group.api_private.id
  description       = "Allow_all_outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# 5) S3 bucket

resource "aws_s3_bucket" "app" {
  # bucket_prefix laat AWS/Terraform een unieke naam genereren.
  bucket_prefix = "${var.name}-"
  force_destroy = var.s3_force_destroy

  tags = {
    Project = "RAG"
    Env     = "dev"
  }
}

resource "aws_s3_bucket_public_access_block" "app" {
  bucket = aws_s3_bucket.app.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "app" {
  bucket = aws_s3_bucket.app.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app" {
  bucket = aws_s3_bucket.app.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "app" {
  bucket = aws_s3_bucket.app.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}



# 6) ECR (Elastic Container Registry)

resource "aws_ecr_repository" "app" {
  name         = var.ecr_repository_name
  force_delete = var.ecr_force_delete

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Project = "RAG"
    Env     = "dev"
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than X days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.ecr_expire_untagged_days
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only last N tagged images"
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*"] # <-- FIX: match alle tags
          countType      = "imageCountMoreThan"
          countNumber    = var.ecr_keep_last_tagged
        }
        action = { type = "expire" }
      }
    ]
  })
}
