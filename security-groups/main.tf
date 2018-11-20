variable "name" {
  description = "The name of the security groups serves as a prefix, e.g stack"
  default     = "default"
}

variable "environment" {
  description = "The environment, used for tagging, e.g prod"
  default     = "dev"
}

variable "vpc_id" {
  description = "The VPC ID"
}

variable "cidr_block" {
  description = "The cidr block to use for internal security groups"
  default     = "10.0.0.0/16"
}

resource "aws_security_group" "internal_elb" {
  name        = "${format("%s-%s-internal-elb", var.name, var.environment)}"
  vpc_id      = "${var.vpc_id}"
  description = "Allows internal ELB traffic"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.cidr_block}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "external_elb" {
  name        = "${format("%s-%s-external-elb", var.name, var.environment)}"
  vpc_id      = "${var.vpc_id}"
  description = "Allows external ELB traffic"

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
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "external_ssh" {
  name        = "${format("%s-%s-external-ssh", var.name, var.environment)}"
  description = "Allows ssh from the world"
  vpc_id      = "${var.vpc_id}"

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

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "internal_ssh" {
  name        = "${format("%s-%s-internal-ssh", var.name, var.environment)}"
  description = "Allows ssh from bastion"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = ["${aws_security_group.external_ssh.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["${var.cidr_block}"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

output "external_ssh" {
  value = "${aws_security_group.external_ssh.id}"
}

output "internal_ssh" {
  value = "${aws_security_group.internal_ssh.id}"
}

output "internal_elb" {
  value = "${aws_security_group.internal_elb.id}"
}

output "external_elb" {
  value = "${aws_security_group.external_elb.id}"
}
