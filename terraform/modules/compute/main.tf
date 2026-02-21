# modules/compute/main.tf
# This file creates:
#   - Security Groups (firewall rules for each component)
#   - IAM Role (permission badge that EC2 wears to talk to CloudWatch)
#   - Application Load Balancer (traffic cop that distributes requests)
#   - Auto Scaling Group (automatically adds/removes EC2s based on load)
#   - ElastiCache Redis (fast in-memory store for sessions/caching)

# ─── SECURITY GROUPS ──────────────────────────────────────────────────────────

# ALB Security Group — allows internet HTTP/HTTPS traffic
resource "aws_security_group" "alb" {
  name        = "${var.project}-alb-sg"
  description = "Allow HTTP/HTTPS from internet"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-alb-sg" }
}

# EC2 Security Group — only accepts traffic from the ALB (not the open internet)
resource "aws_security_group" "backend" {
  name        = "${var.project}-backend-sg"
  description = "Allow traffic only from ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # SSH — only for debugging (consider removing in production)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-backend-sg" }
}

# Redis Security Group — only accepts traffic from EC2 backend
resource "aws_security_group" "redis" {
  name        = "${var.project}-redis-sg"
  description = "Allow Redis traffic from backend only"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-redis-sg" }
}

# ─── IAM ROLE FOR EC2 ─────────────────────────────────────────────────────────
# This gives EC2 instances permission to write logs to CloudWatch

resource "aws_iam_role" "ec2_role" {
  name = "${var.project}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# ─── LOAD BALANCER ────────────────────────────────────────────────────────────

resource "aws_lb" "main" {
  name               = "${var.project}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  tags = { Environment = var.environment }
}

resource "aws_lb_target_group" "backend" {
  name     = "${var.project}-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# ─── LAUNCH TEMPLATE (EC2 blueprint) ──────────────────────────────────────────

resource "aws_launch_template" "backend" {
  name_prefix   = "${var.project}-backend-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  vpc_security_group_ids = [aws_security_group.backend.id]

  # user_data runs when the EC2 first boots — installs Docker and starts the app
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    mongo_uri      = var.mongo_uri
    redis_endpoint = var.redis_endpoint
    frontend_url   = var.frontend_url
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.project}-backend"
      Environment = var.environment
    }
  }
}

# ─── AUTO SCALING GROUP ───────────────────────────────────────────────────────
# Keeps min 1 EC2, max 3. Adds more when CPU > 70%, removes when < 30%

resource "aws_autoscaling_group" "backend" {
  name                = "${var.project}-asg"
  desired_capacity    = 1
  min_size            = 1
  max_size            = 3
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.backend.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project}-backend"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project}-scale-up"
  autoscaling_group_name = aws_autoscaling_group.backend.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project}-scale-down"
  autoscaling_group_name = aws_autoscaling_group.backend.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

# ─── ELASTICACHE REDIS ────────────────────────────────────────────────────────

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project}-redis-subnet-group"
  subnet_ids = var.private_subnet_ids
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.project}-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro" # Cheapest option — fits budget
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.redis.id]

  tags = { Environment = var.environment }
}
