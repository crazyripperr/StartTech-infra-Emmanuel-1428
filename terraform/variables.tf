variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name used to prefix all resources"
  type        = string
  default     = "starttech"
}

variable "environment" {
  description = "Deployment environment (prod, staging)"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type for the backend"
  type        = string
  default     = "t3.micro" # Free-tier eligible, fits your $41 budget
}

variable "key_name" {
  description = "Name of existing EC2 key pair for SSH access"
  type        = string
}

variable "ami_id" {
  description = "Amazon Machine Image ID (Ubuntu 22.04 in us-east-1)"
  type        = string
  default     = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS us-east-1
}

variable "mongo_uri" {
  description = "MongoDB Atlas connection string"
  type        = string
  sensitive   = true # Terraform won't print this in logs
}
