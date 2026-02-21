# modules/monitoring/main.tf
# CloudWatch = AWS's built-in monitoring tool.
# Log Groups = folders that collect and store logs from your app.
# Alarms = alerts that fire when something goes wrong (e.g., CPU too high).

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/starttech/backend"
  retention_in_days = 7 # Keep logs for 7 days (longer = more expensive)

  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_log_group" "frontend_access" {
  name              = "/starttech/frontend-access"
  retention_in_days = 7

  tags = { Environment = var.environment }
}

# Alarm: Fire if average CPU > 80% for 2 consecutive 5-minute periods
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Backend CPU usage is above 80%"

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }

  tags = { Environment = var.environment }
}

# Alarm: Fire if the Load Balancer returns a lot of 5xx errors
resource "aws_cloudwatch_metric_alarm" "alb_errors" {
  alarm_name          = "${var.project}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "ALB is returning too many 5xx errors"

  dimensions = {
    LoadBalancer = var.alb_arn
  }

  tags = { Environment = var.environment }
}
