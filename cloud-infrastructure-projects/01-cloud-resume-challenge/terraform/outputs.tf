output "website_url" {
  description = "URL of the resume website"
  value       = "https://${var.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.website.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.website.domain_name
}

output "s3_bucket_name" {
  description = "S3 bucket name for website hosting"
  value       = aws_s3_bucket.website.id
}

output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = aws_apigatewayv2_api.visitor_api.api_endpoint
}

output "api_custom_domain" {
  description = "API custom domain URL"
  value       = "https://api.${var.domain_name}"
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.visitor_counter.function_name
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.visitor_counter.name
}

output "github_actions_access_key_id" {
  description = "Access key ID for GitHub Actions (sensitive)"
  value       = aws_iam_access_key.github_actions.id
  sensitive   = true
}

output "github_actions_secret_access_key" {
  description = "Secret access key for GitHub Actions (sensitive)"
  value       = aws_iam_access_key.github_actions.secret
  sensitive   = true
}

output "certificate_arn" {
  description = "ACM certificate ARN"
  value       = aws_acm_certificate.website.arn
}
