provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "shreyassp_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "shreyassp_public_subnet" {
  vpc_id            = aws_vpc.shreyassp_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "shreyassp_private_subnet" {
  vpc_id            = aws_vpc.shreyassp_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_internet_gateway" "shreyassp_igw" {
  vpc_id = aws_vpc.shreyassp_vpc.id
}

resource "aws_route_table" "shreyassp_route_table" {
  vpc_id = aws_vpc.shreyassp_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.shreyassp_igw.id
  }
}

resource "aws_route_table_association" "shreyassp_route_table_association" {
  subnet_id      = aws_subnet.shreyassp_public_subnet.id
  route_table_id = aws_route_table.shreyassp_route_table.id
}

resource "aws_security_group" "shreyassp_sg" {
  vpc_id = aws_vpc.shreyassp_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
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

resource "aws_iam_role" "shreyassp_ec2_role" {
  name               = "shreyassp_ec2_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "shreyassp_s3_access" {
  name        = "shreyassp_s3_access"
  description = "IAM policy for EC2 instance to access S3"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Effect = "Allow"
        Resource = "arn:aws:s3:::shreyassp_s3/*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "shreyassp_attach_policy" {
  policy_arn = aws_iam_policy.shreyassp_s3_access.arn
  role       = aws_iam_role.shreyassp_ec2_role.name
}

resource "aws_instance" "shreyassp_ec2" {
  ami                    = "ami-0c55b159cbfafe1f0"  # Example AMI ID, replace with actual
  instance_type         = "t2.micro"
  subnet_id             = aws_subnet.shreyassp_public_subnet.id
  security_groups       = [aws_security_group.shreyassp_sg.name]
  iam_instance_profile   = aws_iam_role.shreyassp_ec2_role.name
  
  tags = {
    Name = "shreyassp_ec2"
  }
}

resource "aws_s3_bucket" "shreyassp_s3" {
  bucket = "shreyassp_s3"
  acl    = "private"
}