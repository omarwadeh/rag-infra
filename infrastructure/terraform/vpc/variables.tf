variable "region" {
  type    = string
  default = "eu-central-1" # Frankfurt
}

variable "name" {
  type    = string
  default = "rag-vpc"
}

variable "azs" {
  type    = list(string)
  default = ["eu-central-1a", "eu-central-1b"]
}

variable "cidr" {
  type    = string
  default = "192.168.0.0/16"
}

variable "single_nat_gateway" {
  type    = bool
  default = false
}

variable "api_port" {
  type    = number
  default = 8000
}

variable "s3_force_destroy" {
  type = bool
  # true = bucket mag leeggegooid/verwijderd worden bij terraform destroy
  default = true
}

variable "ecr_repository_name" {
  type    = string
  default = "rag-app"
}

variable "ecr_force_delete" {
  type = bool
  # true = repository mag leeggegooid worden bij terraform destroy
  default = true
}

variable "ecr_expire_untagged_days" {
  type    = number
  default = 14
}

variable "ecr_keep_last_tagged" {
  type    = number
  default = 30
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "ecr_repository_arn" {
  value = aws_ecr_repository.app.arn
}