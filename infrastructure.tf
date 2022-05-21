terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.63"
    }
    random = {
      source  = "hashicorp/aws"
      version = ">=3.0.0"
    }
  }

  cloud {
    organization = "Dataalgebra-Cloud"

    workspaces {
      name = "AWS-DataalgebraCloud"
    }
  }
}

# VPC
resource "aws_vpc" "vpc" {
  cidr_block        = var.vpc_cidr
  instance_tenancy  = "default"

  tags = {
    Name = "${var.PREFIX}-vpc"
  }
}

# Internet Gateway for the Public Subnets
resource "aws_internet_gateway" "int_gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.PREFIX}_int_gateway"
  }
}

# Private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "ap-northeast-1c"

  tags = {
    Name = "${var.PREFIX}_private_subnet"
  }
}

# Public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.public_subnet_cidr
  availability_zone = "ap-northeast-1c"

  tags = {
    Name = "${var.PREFIX}_public_subnet"
  }
}

# Nat Gateway for private subnet
resource "aws_eip" "nat_gateway_eip" {
  vpc = true
  tags = {
    Name = "${var.PREFIX}_nat_gateway_eip"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "${var.PREFIX}_nat_gateway"
  }
}

# Public route table
resource "aws_route_table" "route_table_public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.int_gateway.id
  }

  tags = {
    Name = "${var.PREFIX}_public"
  }
}

# Private route table
resource "aws_route_table" "route_table_private" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name = "${var.PREFIX}_private"
  }
}

# Associations
resource "aws_route_table_association" "assoc_1" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.route_table_public.id
}

resource "aws_route_table_association" "assoc_2" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.route_table_private.id
}
  

# ECR repository
resource "aws_ecr_repository" "ECR_repository" {
  name                 = var.PREFIX
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ECS cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.PREFIX}-cluster"
  capacity_providers = [
  "FARGATE"]
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Task execution role for used for ECS
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.PREFIX}_ecs_task_execution_role"

  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

# Attach policy to task execution role
resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "admin-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}


# Task definition
resource "aws_cloudwatch_log_group" "ecs-log-group" {
  name = "/ecs/${var.PREFIX}-task-def"
}

resource "aws_ecs_task_definition" "task_definition" {
  family                   = "${var.PREFIX}-task-def"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = "1024"   
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  container_definitions    = <<TASK_DEFINITION
  [
    {
      "name": "ecs-runner",
      "image": "106878672844.dkr.ecr.us-east-2.amazonaws.com/ecs-runner:latest",
      "cpu": 256,
      "memory": 512,
      "essential": true,
      "network_mode": "awsvpc",
      "portMappings": [
        {
            "containerPort": 80
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-region" : "us-east-2",
            "awslogs-group" : "/ecs/${var.PREFIX}-task-def",
            "awslogs-stream-prefix" : "ecs"
        }
      },
      "command": ["./start.sh"],
      "environment": [{
        "name": "PAT",
        "value": "${var.PREFIX}-PAT"
      },
      {
        "name": "ORG",
        "value": "${var.PREFIX}-ORG"
      },
      {
        "name": "REPO",
        "value": "${var.PREFIX}-REPO"
      },
      {
        "name": "AWS_REGION",
        "value": "${var.PREFIX}-AWS_REGION"
      },
      {
        "name": "AWS_SECRET_ACCESS_KEY",
        "value": "${var.PREFIX}-AWS_SECRET_ACCESS_KEY"
      },
      {
        "name": "AWS_ACCESS_KEY_ID",
        "value": "${var.PREFIX}-AWS_ACCESS_KEY_ID"
      }]
    }
  ]
  TASK_DEFINITION
}

# A security group for ECS
resource "aws_security_group" "ecs_sg" {
  name        = "${var.PREFIX}-ecs-sg"
  description = "Allow incoming traffic for ecs"
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.PREFIX}_ecs_sg"
  }
}

resource "aws_ecs_service" "ecs_service" {
  name            = "${var.PREFIX}-ecs-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.task_definition.arn
  desired_count   = "1"
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_sg.id]
    subnets          = [aws_subnet.private_subnet.id]
    assign_public_ip = false
  }
}

# Autoscaling
resource "aws_appautoscaling_target" "dev_to_target" {
  max_capacity       = 2
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.ecs_cluster.name}/${aws_ecs_service.ecs_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "dev_to_memory" {
  name               = "dev-to-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dev_to_target.resource_id
  scalable_dimension = aws_appautoscaling_target.dev_to_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.dev_to_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value = 80
  }
}

resource "aws_appautoscaling_policy" "dev_to_cpu" {
  name               = "dev-to-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dev_to_target.resource_id
  scalable_dimension = aws_appautoscaling_target.dev_to_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.dev_to_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value = 60
  }
}


