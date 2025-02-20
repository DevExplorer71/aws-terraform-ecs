#---------------------------
# VPC, Subnets & Security Group
#---------------------------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "public2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

resource "aws_security_group" "ecs_sg" {
  name        = "ecs-sg"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.main.id

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

#---------------------------
# IAM Roles for ECS Tasks
#---------------------------
resource "aws_iam_role" "ecs_task_execution_rolea" {
  name = "ecsTaskExecutionRolea"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_rolea.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# (Optional) Task Role if your container needs to assume additional permissions.
resource "aws_iam_role" "ecs_task_starting_role" {
  name = "ecsTaskRolea"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

#---------------------------
# ECS Cluster
#---------------------------
resource "aws_ecs_cluster" "first-cluster" {
  name = "genesis-cluster"
}

#---------------------------
# Custom ECS Task Definition
#---------------------------
resource "aws_ecs_task_definition" "first-ecs-task" {
  family                   = "first-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"  # 0.25 vCPU
  memory                   = "512"  # 512 MB
  execution_role_arn       = aws_iam_role.ecs_task_starting_role.arn
  task_role_arn            = aws_iam_role.ecs_task_starting_role.arn

  container_definitions = jsonencode([
    {
      name      = "my-app"
      image     = "nginx:latest"
      cpu       = 256,
      memory    = 512,
      essential = true,
      portMappings = [
        {
          containerPort = 80,
          hostPort      = 80,
          protocol      = "tcp"
        }
      ]
    }
  ])
}

#---------------------------
# ECS Service
#---------------------------
resource "aws_ecs_service" "example" {
  name            = "example-service"
  cluster         = aws_ecs_cluster.first-cluster.arn
  task_definition = aws_ecs_task_definition.first-ecs-task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.public1.id, aws_subnet.public2.id]
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }
}




