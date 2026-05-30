provider "aws" {
  region = var.aws_region
}

resource "aws_security_group" "devops_sg" {
  name        = "devops-security-group"
  description = "Security group for DevOps project"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
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

resource "aws_instance" "terraform_server" {
  ami                    = "ami-0f58b397bc5c1f2e8"
  instance_type          = var.instance_type
  key_name               = "devops-key"
  vpc_security_group_ids = [aws_security_group.devops_sg.id]

  user_data = file("${path.module}/userdata.sh")

  tags = {
    Name = "terraform-server"
  }
}