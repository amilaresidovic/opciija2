output "alb_dns_name" {
  value       = aws_lb.app_alb.dns_name
  description = "ALB DNS name"
}

output "application_url" {
  value       = "http://${aws_lb.app_alb.dns_name}"
  description = "URL za pristup aplikaciji"
}

output "rds_endpoint" {
  value       = aws_db_instance.app_db.endpoint
  description = "RDS endpoint"
}