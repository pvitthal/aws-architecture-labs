locals {
  name = "lab06-scheduled-task"
  task_assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  events_assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_vpc" "task" {
  cidr_block = "10.60.0.0/16"
}

resource "aws_subnet" "task" {
  vpc_id            = aws_vpc.task.id
  cidr_block        = "10.60.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_security_group" "task" {
  name        = "${local.name}-sg"
  description = "No ingress; permits task egress."
  vpc_id      = aws_vpc.task.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_cluster" "tasks" {
  name = "${local.name}-cluster"
}

resource "aws_iam_role" "task_execution" {
  name               = "${local.name}-execution-role"
  assume_role_policy = local.task_assume_role_policy
}

resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "eventbridge" {
  name               = "${local.name}-eventbridge-role"
  assume_role_policy = local.events_assume_role_policy
}

resource "aws_iam_role_policy" "eventbridge_ecs" {
  name = "${local.name}-run-task"
  role = aws_iam_role.eventbridge.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["ecs:RunTask"], Resource = aws_ecs_task_definition.worker.arn },
      { Effect = "Allow", Action = ["iam:PassRole"], Resource = aws_iam_role.task_execution.arn },
    ]
  })
}

resource "aws_ecs_task_definition" "worker" {
  family                   = "${local.name}-worker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.task_execution.arn

  depends_on = [aws_iam_role_policy_attachment.task_execution]

  container_definitions = jsonencode([{
    name      = "worker"
    image     = "public.ecr.aws/amazonlinux/amazonlinux:2023"
    essential = true
    command   = ["sh", "-c", "echo eventbridge-task-started; exit 0"]
  }])
}

resource "aws_cloudwatch_event_rule" "run_task" {
  name        = "${local.name}-run"
  description = "Runs one short Fargate task for a lab event."
  event_pattern = jsonencode({
    source        = ["lab.architecture"]
    "detail-type" = ["run-task"]
  })
}

resource "aws_cloudwatch_event_target" "ecs" {
  rule     = aws_cloudwatch_event_rule.run_task.name
  arn      = aws_ecs_cluster.tasks.arn
  role_arn = aws_iam_role.eventbridge.arn

  ecs_target {
    task_definition_arn = aws_ecs_task_definition.worker.arn
    task_count          = 1
    launch_type         = "FARGATE"
    network_configuration {
      subnets          = [aws_subnet.task.id]
      security_groups  = [aws_security_group.task.id]
      assign_public_ip = false
    }
  }
}
