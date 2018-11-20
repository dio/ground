variable "cidr_block" {
  description = "VPC CIDR block"
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs"
  default     = ["ap-southeast-1a"]
}

variable "internal_subnets" {
  description = "Internal subnets"
  default     = ["10.0.1.0/24"]
}

variable "external_subnets" {
  description = "External subnets"
  default     = ["10.0.101.0/24"]
}

variable "nat_instance_type" {
  description = "NAT instance type"
  default     = "t2.nano"
}

// VPC
resource "aws_vpc" "main" {
  cidr_block           = "${var.cidr_block}"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

// Internet gateway
resource "aws_internet_gateway" "main" {
  vpc_id = "${aws_vpc.main.id}"
}

// NAT instances
data "aws_ami" "nat_ami" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn-ami-vpc-nat*"]
  }
}

resource "aws_instance" "nat_instance" {
  count                  = "${length(var.internal_subnets)}"
  availability_zone      = "${element(var.availability_zones, count.index)}"
  ami                    = "${data.aws_ami.nat_ami.id}"
  instance_type          = "${var.nat_instance_type}"
  source_dest_check      = false
  subnet_id              = "${element(aws_subnet.external.*.id, count.index)}"
  vpc_security_group_ids = ["${aws_security_group.nat_instances.id}"]

  lifecycle {
    ignore_changes = ["ami"]
  }
}

resource "aws_eip" "nat" {
  count = "${length(compact(var.internal_subnets))}"
  vpc   = true
}

resource "aws_eip_association" "nat_instance_eip" {
  count         = "${length(compact(var.internal_subnets))}"
  instance_id   = "${element(aws_instance.nat_instance.*.id, count.index)}"
  allocation_id = "${element(aws_eip.nat.*.id, count.index)}"
}

resource "aws_security_group" "nat_instances" {
  name        = "nat"
  description = "Allow traffic from clients into NAT instances"

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = "${var.internal_subnets}"
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = "${var.internal_subnets}"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = "${aws_vpc.main.id}"
}

// External subnet
resource "aws_subnet" "external" {
  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "${element(var.external_subnets, count.index)}"
  availability_zone       = "${element(var.availability_zones, count.index)}"
  count                   = "${length(compact(var.external_subnets))}"
  map_public_ip_on_launch = true
}

// Internal subnet
resource "aws_subnet" "internal" {
  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "${element(var.internal_subnets, count.index)}"
  availability_zone       = "${element(var.availability_zones, count.index)}"
  count                   = "${length(compact(var.internal_subnets))}"
  map_public_ip_on_launch = false
}

// Routing
resource "aws_route_table" "external" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_route" "external" {
  route_table_id         = "${aws_route_table.external.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.main.id}"
}

resource "aws_route_table_association" "external" {
  count          = "${length(compact(var.external_subnets))}"
  subnet_id      = "${element(aws_subnet.external.*.id, count.index)}"
  route_table_id = "${aws_route_table.external.id}"
}

resource "aws_route_table" "internal" {
  count  = "${length(compact(var.internal_subnets))}"
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_route" "internal" {
  count                  = "${length(compact(var.internal_subnets))}"
  route_table_id         = "${element(aws_route_table.internal.*.id, count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  instance_id            = "${element(aws_instance.nat_instance.*.id, count.index)}"
}

resource "aws_route_table_association" "internal" {
  count          = "${length(compact(var.internal_subnets))}"
  subnet_id      = "${element(aws_subnet.internal.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.internal.*.id, count.index)}"
}

output "id" {
  value = "${aws_vpc.main.id}"
}

output "cidr_block" {
  value = "${aws_vpc.main.cidr_block}"
}

output "internal_subnets" {
  value = ["${aws_subnet.internal.*.id}"]
}

output "external_subnets" {
  value = ["${aws_subnet.external.*.id}"]
}

output "availability_zones" {
  value = ["${aws_subnet.external.*.availability_zone}"]
}
