variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "bastion_sg_id" {
  description = "Security group ID for bastion"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for bastion instance"
  type        = string
}

variable "instance_type" {
  description = "Instance type for bastion"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM instance profile name for bastion"
  type        = string
  default     = ""
}

variable "allocate_eip" {
  description = "Allocate an Elastic IP for the bastion"
  type        = bool
  default     = true
}
