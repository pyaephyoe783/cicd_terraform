terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "my-tf-state-bucket-ye-yint-2026"
    key          = "global/s3/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}



resource "aws_vpc" "main_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "Enterprise-Custom-VPC"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "Custom-VPC-IGW"
  }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = {
    Name = "NAT-EIP"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id
  depends_on    = [aws_internet_gateway.igw]

  tags = {
    Name = "NAT-Gateway"
  }
}



resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public-Subnet-1a"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Public-Subnet-1b"
  }
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "Private-Subnet-1a"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "Private-Subnet-1b"
  }
}



resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public-Route-Table"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "Private-Route-Table"
  }
}

resource "aws_route_table_association" "public_assoc_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_assoc_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}



resource "aws_security_group" "alb_sg" {
  name        = "alb-security-group"
  vpc_id      = aws_vpc.main_vpc.id
  description = "Allow HTTP inbound traffic to ALB"

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
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2-security-group"
  vpc_id      = aws_vpc.main_vpc.id
  description = "Allow HTTP from ALB and SSH"

  ingress {
    from_port       = 80
    to_port         = 80
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
}



data "aws_ami" "ubuntu_golden" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}



resource "aws_instance" "web_sever_1" {
  ami                    = data.aws_ami.ubuntu_golden.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_subnet_1.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  depends_on             = [aws_nat_gateway.nat_gw]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm_profile.name

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y nginx
              sudo systemctl start nginx
              sudo systemctl enable nginx
              echo "<h1>Welcome to Web Server 1</h1>" | sudo tee /var/www/html/index.html
              EOF

  tags = {
    Name = "Web-Server-1"
  }
}

resource "aws_instance" "web_sever_2" {
  ami                    = data.aws_ami.ubuntu_golden.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_subnet_2.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  depends_on             = [aws_nat_gateway.nat_gw]
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm_profile.name

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y nginx
              sudo systemctl start nginx
              sudo systemctl enable nginx
              echo "<h1>Welcome to Web Server 2</h1>" | sudo tee /var/www/html/index.html
              EOF

  tags = {
    Name = "Web-Server-2"
  }    
}



resource "aws_lb_target_group" "web_tg" {
  name     = "web-sever-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main_vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "Web-Server-TG"
  }
}

resource "aws_lb_target_group_attachment" "web_tg_attachment_1" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web_sever_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "web_tg_attachment_2" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web_sever_2.id
  port             = 80
}

resource "aws_lb" "web_alb" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  tags = {
    Name = "Web-ALB"
  }
}

resource "aws_lb_listener" "web_alb_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}


resource "aws_db_subnet_group" "rds_subent_group_v2"{
  name       = "main-rds-subnet-group-v2"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]

  tags = {
    Name = "Main-RDS-Subnet-Group"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "rds-security-group"
  vpc_id      = aws_vpc.main_vpc.id
  description = "Allow MySQL access from EC2 instances"

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "main_rds" {
  allocated_storage    = 20
  max_allocated_storage = 100
  engine               = "postgres"
  engine_version       = "15"
  instance_class       = "db.t4g.micro"

  db_name               = "appdb"
  username              = "dbadmin"
  password              = var.db_password

  db_subnet_group_name = aws_db_subnet_group.rds_subent_group_v2.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  publicly_accessible = false
  skip_final_snapshot   = true
  deletion_protection = false  // ဖျက်တာမြန်အောင်ထည့်ထားတာမသုံးသင့်

  tags = {
    Name = "Main-RDS-Instance"
  } 
} 