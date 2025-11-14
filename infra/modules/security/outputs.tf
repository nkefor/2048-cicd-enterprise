# Security Module Outputs

output "kms_key_id" {
  description = "KMS Key ID for PHI encryption"
  value       = aws_kms_key.phi_encryption.id
}

output "kms_key_arn" {
  description = "KMS Key ARN for PHI encryption"
  value       = aws_kms_key.phi_encryption.arn
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.healthcare.id
}

output "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN"
  value       = aws_cognito_user_pool.healthcare.arn
}

output "cognito_user_pool_endpoint" {
  description = "Cognito User Pool Endpoint"
  value       = aws_cognito_user_pool.healthcare.endpoint
}

output "cognito_user_pool_client_id" {
  description = "Cognito User Pool Client ID"
  value       = aws_cognito_user_pool_client.healthcare.id
  sensitive   = true
}

output "cognito_identity_pool_id" {
  description = "Cognito Identity Pool ID"
  value       = aws_cognito_identity_pool.healthcare.id
}

output "waf_web_acl_id" {
  description = "WAF Web ACL ID"
  value       = aws_wafv2_web_acl.api_protection.id
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN"
  value       = aws_wafv2_web_acl.api_protection.arn
}

output "lambda_security_group_id" {
  description = "Lambda Security Group ID"
  value       = aws_security_group.lambda.id
}
