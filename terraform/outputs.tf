output "cloudfront_domain" {
  description = "CloudFront URL to access the React frontend"
  value       = module.storage.cloudfront_domain
}

output "alb_dns_name" {
  description = "Load Balancer DNS — point your backend API calls here"
  value       = module.compute.alb_dns_name
}

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = module.compute.redis_endpoint
  sensitive   = true
}

output "s3_bucket_name" {
  description = "S3 bucket where frontend files are uploaded"
  value       = module.storage.bucket_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (needed to invalidate cache after deploy)"
  value       = module.storage.cloudfront_distribution_id
}
