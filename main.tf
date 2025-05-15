provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "clouvixproject_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "clouvixproject_public_subnet" {
  vpc_id            = aws_vpc.clouvixproject_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "clouvixproject_private_subnet" {
  vpc_id            = aws_vpc.clouvixproject_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_internet_gateway" "clouvixproject_igw" {
  vpc_id = aws_vpc.clouvixproject_vpc.id
}

resource "aws_route_table" "clouvixproject_route_table" {
  vpc_id = aws_vpc.clouvixproject_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.clouvixproject_igw.id
  }
}

resource "aws_route_table_association" "clouvixproject_public_route_table_association" {
  subnet_id      = aws_subnet.clouvixproject_public_subnet.id
  route_table_id = aws_route_table.clouvixproject_route_table.id
}

resource "aws_security_group" "clouvixproject_ec2_sg" {
  vpc_id = aws_vpc.clouvixproject_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.2.0/24"] # private subnet CIDR
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "clouvixproject_ec2_role" {
  name = "clouvixproject_ec2_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "clouvixproject_ec2_policy" {
  name        = "clouvixproject_ec2_policy"
  description = "Policy for EC2 role to access required services."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["rds:DescribeDBInstances"],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "clouvixproject_attach_policy" {
  role       = aws_iam_role.clouvixproject_ec2_role.name
  policy_arn = aws_iam_policy.clouvixproject_ec2_policy.arn
}

resource "aws_instance" "clouvixproject_ec2" {
  ami           = "ami-0c55b159cbfafe1f0" # Example AMI, replace accordingly
  instance_type = "t2.micro"
  security_groups = [aws_security_group.clouvixproject_ec2_sg.name]
  subnet_id     = aws_subnet.clouvixproject_public_subnet.id
  iam_instance_profile = aws_iam_instance_profile.clouvixproject_ec2_profile.name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y java
              EOF
}

resource "aws_iam_instance_profile" "clouvixproject_ec2_profile" {
  name = "clouvixproject_ec2_profile"
  role = aws_iam_role.clouvixproject_ec2_role.name
}

resource "aws_db_subnet_group" "clouvixproject_db_subnet_group" {
  name       = "clouvixproject_db_subnet_group"
  subnet_ids = [aws_subnet.clouvixproject_private_subnet.id]

  tags = {
    Name = "clouvixproject_db_subnet_group"
  }
}

resource "aws_security_group" "clouvixproject_rds_sg" {
  vpc_id = aws_vpc.clouvixproject_vpc.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"] # Allow public subnet to access RDS
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "clouvixproject_rds" {
  identifier         = "clouvixproject-rds"
  instance_class     = "db.t3.micro"
  engine             = "postgres"
  allocated_storage   = 20
  storage_type       = "gp2"
  db_subnet_group_name = aws_db_subnet_group.clouvixproject_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.clouvixproject_rds_sg.id]
  username           = "admin"
  password           = "shreyas1234@1234" # Use secrets manager for production
  skip_final_snapshot = true
}