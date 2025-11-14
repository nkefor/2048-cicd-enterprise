# Governance Module Outputs

output "scp_policy_ids" {
  description = "Map of SCP policy IDs"
  value = var.organization_id != "" ? {
    encryption_in_transit    = aws_organizations_policy.require_encryption_in_transit[0].id
    encryption_at_rest       = aws_organizations_policy.require_encryption_at_rest[0].id
    restrict_regions         = length(var.allowed_regions) > 0 ? aws_organizations_policy.restrict_regions[0].id : null
    prevent_public_s3        = aws_organizations_policy.prevent_public_s3_buckets[0].id
    require_mfa              = var.require_mfa ? aws_organizations_policy.require_mfa[0].id : null
    require_cloudtrail       = aws_organizations_policy.require_cloudtrail[0].id
    protect_security_controls = aws_organizations_policy.protect_security_controls[0].id
  } : {}
}

output "scp_count" {
  description = "Number of SCPs created"
  value       = var.organization_id != "" ? 7 : 0
}
