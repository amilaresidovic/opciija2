variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t3.micro"
}

variable "rds_instance_type" {
  description = "RDS instance type"
  default     = "db.t3.micro"
}

variable "repo_url" {
  description = "Git repository URL"
  default     = "https://github.com/amilaresidovic/opciija2.git"
}

variable "health_check_timeout" {
  description = "Maximum time to wait for health checks (in minutes)"
  type        = number
  default     = 10
}