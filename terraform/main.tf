terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Store state remotely so the team shares one source of truth
  backend "s3" {
    bucket = "starttech-emmanuel-tfstate"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

# ─── NETWORKING ───────────────────────────────────────────────────────────────
module "networking" {
  source = "./modules/networking"

  project     = var.project
  environment = var.environment
  vpc_cidr    = var.vpc_cidr
}

# ─── STORAGE (S3 + CloudFront for React frontend) ─────────────────────────────
module "storage" {
  source = "./modules/storage"

  project     = var.project
  environment = var.environment
}

# ─── COMPUTE (EC2 ASG + ALB + ElastiCache) ────────────────────────────────────
module "compute" {
  source = "./modules/compute"

  project            = var.project
  environment        = var.environment
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids
  instance_type      = var.instance_type
  key_name           = var.key_name
  ami_id             = var.ami_id
  mongo_uri          = var.mongo_uri
  redis_endpoint     = module.compute.redis_endpoint
  frontend_url       = module.storage.cloudfront_domain
}

# ─── MONITORING (CloudWatch) ──────────────────────────────────────────────────
module "monitoring" {
  source = "./modules/monitoring"

  project     = var.project
  environment = var.environment
  asg_name    = module.compute.asg_name
  alb_arn     = module.compute.alb_arn
}
