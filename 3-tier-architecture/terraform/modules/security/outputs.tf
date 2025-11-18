output "alb_sg_id" {
  description = "ID of ALB security group"
  value       = aws_security_group.alb.id
}

output "app_sg_id" {
  description = "ID of application security group"
  value       = aws_security_group.app.id
}

output "database_sg_id" {
  description = "ID of database security group"
  value       = aws_security_group.database.id
}

output "bastion_sg_id" {
  description = "ID of bastion security group"
  value       = aws_security_group.bastion.id
}

output "ec2_iam_role_arn" {
  description = "ARN of EC2 IAM role"
  value       = aws_iam_role.ec2_role.arn
}

output "ec2_instance_profile_name" {
  description = "Name of EC2 instance profile"
  value       = aws_iam_instance_profile.ec2_profile.name
}

output "ec2_instance_profile_arn" {
  description = "ARN of EC2 instance profile"
  value       = aws_iam_instance_profile.ec2_profile.arn
}
