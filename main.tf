provider "aws" {}

module "vpc" {
  source = "./vpc"
}

module "security_groups" {
  source     = "./security-groups"
  vpc_id     = "${module.vpc.id}"
  cidr_block = "${module.vpc.cidr_block}"
}

module "bastion" {
  source          = "./bastion"
  key_name        = "box"
  subnet_id       = "${element(module.vpc.external_subnets, 0)}"
  security_groups = "${module.security_groups.external_ssh},${module.security_groups.internal_ssh}"
}

module "ecs_cluster" {
  source   = "./ecs/cluster"
  key_name = "box"

  security_groups = [
    "${module.security_groups.internal_elb}",
    "${module.security_groups.internal_ssh}",
  ]

  vpc_zone_identifier = "${module.vpc.internal_subnets}"
}

// Services here
// DAEMON, REPLICA
// egress, ingress
// internet -> lb -> envoy
// process -> envoy -> nat

resource "aws_service_discovery_private_dns_namespace" "local" {
  name        = "ground.local"
  description = "local"
  vpc         = "${module.vpc.id}"
}

module "nginx" {
  source       = "./services/nginx"
  cluster_id   = "${module.ecs_cluster.id}"
  namespace_id = "${aws_service_discovery_private_dns_namespace.local.id}"
  subnets      = "${module.vpc.internal_subnets}"

  security_groups = [
    "${module.security_groups.internal_elb}",
    "${module.security_groups.internal_ssh}",
  ]
}

output "bastion_external_ip" {
  value = "${module.bastion.external_ip}"
}
