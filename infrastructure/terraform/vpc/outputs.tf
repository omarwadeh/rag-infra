output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_app_subnets" {
  value = module.vpc.private_subnets
}

output "private_data_subnets" {
  value = module.vpc.database_subnets
}
