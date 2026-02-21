variable "project" {}
variable "environment" {}
variable "vpc_id" {}
variable "public_subnet_ids" { type = list(string) }
variable "private_subnet_ids" { type = list(string) }
variable "instance_type" {}
variable "key_name" {}
variable "ami_id" {}
variable "mongo_uri" { sensitive = true }
variable "redis_endpoint" { default = "" }
variable "frontend_url" { default = "" }
