variable "region" {
  type    = string
  default = "eu-central-1"   # Frankfurt
}

variable "name" {
  type    = string
  default = "rag-vpc"
}

variable "azs" {
  type = list(string)
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
