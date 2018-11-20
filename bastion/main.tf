variable "subnet_id" {
  description = "Subnet"
}

variable "key_name" {
  description = "SSH key name"
  default     = "box"
}

variable "security_groups" {
  description = "Security groups"
}

data "aws_ami" "bastion" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "bastion" {
  ami                    = "${data.aws_ami.bastion.id}"
  source_dest_check      = false
  instance_type          = "t2.micro"
  subnet_id              = "${var.subnet_id}"
  vpc_security_group_ids = ["${split(",",var.security_groups)}"]
  monitoring             = true
  user_data              = "${file(format("%s/user-data.sh", path.module))}"
  key_name               = "${var.key_name}"
}

resource "aws_eip" "bastion" {
  instance = "${aws_instance.bastion.id}"
  vpc      = true
}

output "external_ip" {
  value = "${aws_eip.bastion.public_ip}"
}
