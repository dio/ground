variable "cluster_id" {}

variable "namespace_id" {}

variable "subnets" {
  type    = "list"
  default = []
}

variable "security_groups" {
  type    = "list"
  default = []
}

resource "aws_service_discovery_service" "nginx" {
  name = "nginx"

  dns_config {
    namespace_id = "${var.namespace_id}"

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }
}

resource "aws_cloudwatch_log_group" "nginx" {
  name              = "nginx"
  retention_in_days = 1
}

resource "aws_ecs_task_definition" "nginx" {
  family       = "nginx"
  network_mode = "awsvpc"

  container_definitions = <<EOF
[
  {
    "name": "nginx",
    "image": "nginx:1.14.1-alpine",
    "cpu": 128,
    "memory": 128,
    "portMappings": [
      {
        "containerPort": 80,
        "protocol": "tcp"
      }
    ],
    "essential": true,
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-region": "ap-southeast-1",
        "awslogs-group": "nginx",
        "awslogs-stream-prefix": "cluster-test-dev"
      }
    }
  }
]
EOF
}

resource "aws_ecs_service" "nginx" {
  name            = "nginx"
  cluster         = "${var.cluster_id}"
  task_definition = "${aws_ecs_task_definition.nginx.arn}"

  service_registries {
    registry_arn = "${aws_service_discovery_service.nginx.arn}"
  }

  desired_count                      = 1
  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  network_configuration {
    subnets         = ["${var.subnets}"]
    security_groups = ["${var.security_groups}"]
  }

  depends_on = [
    "aws_service_discovery_service.nginx",
  ]
}
