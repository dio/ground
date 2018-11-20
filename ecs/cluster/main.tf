provider "template" {}

variable "name" {
  description = "Cluster name"
  default     = "cluster-test-dev"
}

resource "aws_ecs_cluster" "main" {
  name = "${var.name}"
}

module "instance_policy" "main" {
  source = "../instance-policy"
  name   = "${var.name}"
}

data "aws_ami" "amazon_linux_ecs" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn-ami-*-amazon-ecs-optimized"]
  }

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
}

variable "key_name" {
  default = "box"
}

variable "security_groups" {
  type    = "list"
  default = []
}

variable "vpc_zone_identifier" {
  type    = "list"
  default = []
}

// Launch configuration
resource "aws_launch_configuration" "main" {
  name_prefix                 = "lc-cluster-test-dev-"
  image_id                    = "${data.aws_ami.amazon_linux_ecs.id}"
  instance_type               = "t2.micro"
  iam_instance_profile        = "${module.instance_policy.profile}"
  key_name                    = "${var.key_name}"
  security_groups             = ["${var.security_groups}"]
  associate_public_ip_address = false
  user_data                   = "${data.template_file.user_data.rendered}"
  enable_monitoring           = true
  spot_price                  = ""
  placement_tenancy           = "default"
  ebs_optimized               = false
  ebs_block_device            = []
  ephemeral_block_device      = []
  root_block_device           = []

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "main" {
  name_prefix               = "asg-cluster-test-dev-"
  launch_configuration      = "${aws_launch_configuration.main.id}"
  vpc_zone_identifier       = ["${var.vpc_zone_identifier}"]
  max_size                  = 1
  min_size                  = 0
  desired_capacity          = 1
  load_balancers            = []
  health_check_grace_period = 300
  health_check_type         = "EC2"
  min_elb_capacity          = 0
  wait_for_elb_capacity     = false
  target_group_arns         = []
  default_cooldown          = 300
  force_delete              = false
  termination_policies      = ["Default"]
  suspended_processes       = []
  placement_group           = ""

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]

  metrics_granularity       = "1Minute"
  wait_for_capacity_timeout = 0
  protect_from_scale_in     = false

  lifecycle {
    create_before_destroy = true
  }
}

data "template_file" "user_data" {
  template = "${file("${path.module}/templates/user-data.sh")}"

  vars {
    cluster_name = "${var.name}"
  }
}

output "id" {
  value = "${element(concat(aws_ecs_cluster.main.*.id, list("")), 0)}"
}
