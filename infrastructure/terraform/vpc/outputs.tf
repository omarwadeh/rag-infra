output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_app_subnets" {
  value = module.vpc.private_subnets
}

output "private_data_subnets" {
  value = module.vpc.database_subnets
}

output "igw_id" {
  value = aws_internet_gateway.this.id
}

output "nat_gateway_id" {
  value = aws_nat_gateway.this.id
}

output "public_route_table_ids" {
  value = module.vpc.public_route_table_ids
}

output "private_route_table_ids" {
  value = module.vpc.private_route_table_ids
}

output "api_public_security_group_id" {
  value = aws_security_group.api_public.id
}

output "s3_bucket_name" {
  value = aws_s3_bucket.app.bucket
}

output "api_private_security_group_id" {
  value = aws_security_group.api_private.id
}
