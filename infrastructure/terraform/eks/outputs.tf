output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "oidc_provider" {
  description = "OIDC provider for the cluster"
  value       = module.eks.oidc_provider
}
