terraform {
  required_version = ">= 1.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.34"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "aws" {
  region = var.region
}


resource "aws_vpc" "main" {
  cidr_block           = "172.16.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "projekat2-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "projekat2-igw" }
}

resource "aws_subnet" "public_subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "172.16.10.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags                    = { Name = "projekat2-public-subnet-a" }
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "172.16.11.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true
  tags                    = { Name = "projekat2-public-subnet-b" }
}

resource "aws_subnet" "private_subnet_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "172.16.20.0/24"
  availability_zone = "${var.region}a"
  tags              = { Name = "projekat2-private-subnet-a" }
}

resource "aws_subnet" "private_subnet_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "172.16.21.0/24"
  availability_zone = "${var.region}b"
  tags              = { Name = "projekat2-private-subnet-b" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "projekat2-public-rt" }
}

resource "aws_route_table_association" "public_rt_assoc_a" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rt_assoc_b" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}


resource "aws_security_group" "frontend_sg" {
  vpc_id = aws_vpc.main.id
  name   = "frontend-sg"
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
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
  tags = { Name = "projekat2-frontend-sg" }
}

resource "aws_security_group" "backend_sg" {
  vpc_id = aws_vpc.main.id
  name   = "backend-sg"
  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
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
  tags = { Name = "projekat2-backend-sg" }
}

resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.main.id
  name   = "alb-sg"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "projekat2-alb-sg" }
}

resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.main.id
  name   = "rds-sg"
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "projekat2-rds-sg" }
}


resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "projekat2-rds-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_a.id, aws_subnet.private_subnet_b.id]
  tags = {
    Name = "projekat2-rds-subnet-group"
  }
}

resource "aws_db_instance" "app_db" {
  identifier             = "projekat2-db"
  engine                 = "postgres"
  engine_version         = "15.13"
  instance_class         = var.rds_instance_type
  allocated_storage      = 20
  storage_type           = "gp2"
  db_name                = "app_db"
  username               = "postgres"
  password               = "postgres"
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
  multi_az               = false
  apply_immediately      = true
  tags = {
    Name = "projekat2-db"
  }
}


resource "aws_instance" "frontend_instance" {
  ami                    = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_subnet_a.id
  vpc_security_group_ids = [aws_security_group.frontend_sg.id]
  iam_instance_profile   = "LabInstanceProfile"
  key_name               = "vockey"
  user_data = <<EOF
#!/bin/bash
exec > /var/log/user-data.log 2>&1 
set -x 

sudo yum update -y
sudo yum install -y docker git
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

git clone ${var.repo_url} /home/ec2-user/projekat2
cd /home/ec2-user/projekat2/frontend

sudo sed -i "s|http://localhost:5000|http://${aws_lb.app_alb.dns_name}/api|g" src/config.js
sudo sed -i "s|__ALB_DNS_PLACEHOLDER__|${aws_lb.app_alb.dns_name}|g" vite.config.js

sudo docker build -t frontend .
sudo docker run -d -p 8080:8080 --name frontend frontend
EOF

  tags = {
    Name = "projekat2-frontend-instance"
  }
}

resource "aws_instance" "backend_instance" {
  ami                    = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_subnet_b.id
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  iam_instance_profile   = "LabInstanceProfile"
  key_name               = "vockey"
  depends_on             = [aws_db_instance.app_db]

  user_data = <<EOF
#!/bin/bash
exec > /var/log/user-data.log 2>&1 
set -x 

sudo yum update -y
sudo yum install -y docker git
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

git clone ${var.repo_url} /home/ec2-user/projekat2
cd /home/ec2-user/projekat2/backend


sudo sed -i "s|postgresql://postgres:postgres@db:5432/app_db|postgresql://postgres:postgres@${aws_db_instance.app_db.endpoint}/app_db|g" config.py


sudo docker build -t backend .
sudo docker run -d -p 5000:5000 \
  -e FLASK_APP=main.py \
  -e DATABASE_URL="postgresql://postgres:postgres@${aws_db_instance.app_db.endpoint}/app_db" \
  --name backend backend
EOF

  tags = { Name = "projekat2-backend-instance" }
}


resource "aws_lb" "app_alb" {
  name               = "projekat2-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]
  tags               = { Name = "projekat2-alb" }
}

resource "aws_lb_target_group" "frontend_tg" {
  name        = "frontend-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
  tags = { Name = "projekat2-frontend-tg" }
}

resource "aws_lb_target_group" "backend_tg" {
  name        = "backend-tg"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"
  health_check {
    path                = "/api/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
  tags = { Name = "projekat2-backend-tg" }
}

resource "aws_lb_target_group_attachment" "frontend_tg_attachment" {
  target_group_arn = aws_lb_target_group.frontend_tg.arn
  target_id        = aws_instance.frontend_instance.id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "backend_tg_attachment" {
  target_group_arn = aws_lb_target_group.backend_tg.arn
  target_id        = aws_instance.backend_instance.id
  port             = 5000
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}

resource "aws_lb_listener_rule" "backend_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }
  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

resource "null_resource" "wait_for_health_checks" {
  depends_on = [
    aws_lb_target_group_attachment.frontend_tg_attachment,
    aws_lb_target_group_attachment.backend_tg_attachment,
    aws_instance.frontend_instance,
    aws_instance.backend_instance,
    aws_db_instance.app_db
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Čekam da EC2 instance budu spremne..."
      sleep 120
      
      echo "Provjeram health status target grupa..."
      TIMEOUT=$(($(date +%s) + ${var.health_check_timeout * 60}))
      
      while [ $(date +%s) -lt $TIMEOUT ]; do
        FRONTEND_STATUS=$(aws elbv2 describe-target-health \
          --target-group-arn ${aws_lb_target_group.frontend_tg.arn} \
          --region ${var.region} \
          --query 'TargetHealthDescriptions[0].TargetHealth.State' \
          --output text 2>/dev/null || echo "checking")
        
        BACKEND_STATUS=$(aws elbv2 describe-target-health \
          --target-group-arn ${aws_lb_target_group.backend_tg.arn} \
          --region ${var.region} \
          --query 'TargetHealthDescriptions[0].TargetHealth.State' \
          --output text 2>/dev/null || echo "checking")
        
        echo "Frontend status: $FRONTEND_STATUS"
        echo " Backend status: $BACKEND_STATUS"
        
        if [ "$FRONTEND_STATUS" = "healthy" ] && [ "$BACKEND_STATUS" = "healthy" ]; then
          echo "Svi health checkovi su prošli!"
          echo " Aplikacija je spremna za korištenje!"
          exit 0
        fi
        
        if [ "$FRONTEND_STATUS" = "unhealthy" ] || [ "$BACKEND_STATUS" = "unhealthy" ]; then
          echo " Neki od targeta je unhealthy. Nastavljam čekanje..."
        fi
        
        echo "Čekam još 30 sekundi..."
        sleep 30
      done
      
      echo "Timeout dosegnut. Provjeri AWS konzolu za detaljnije informacije."
      exit 1
    EOT
  }
}