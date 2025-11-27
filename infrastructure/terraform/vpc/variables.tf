variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "name" {
  type    = string
  default = "rag-vpc"
}

variable "azs" {
  type = list(string)
  default = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

variable "cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "single_nat_gateway" {
  type    = bool
  default = false
}
