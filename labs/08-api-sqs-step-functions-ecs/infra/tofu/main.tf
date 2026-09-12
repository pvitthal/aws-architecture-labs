locals {
  name          = "lab08-async-ecs"
  lambda_assume = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }] })
  states_assume = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "states.amazonaws.com" }, Action = "sts:AssumeRole" }] })
  task_assume   = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_sqs_queue" "jobs" { name = "${local.name}-queue" }
resource "aws_dynamodb_table" "jobs" {
  name         = "${local.name}-jobs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute {
    name = "id"
    type = "S"
  }
}
resource "aws_iam_role" "request" {
  name               = "${local.name}-request-role"
  assume_role_policy = local.lambda_assume
}
resource "aws_iam_role" "dispatcher" {
  name               = "${local.name}-dispatcher-role"
  assume_role_policy = local.lambda_assume
}
resource "aws_iam_role" "workflow" {
  name               = "${local.name}-workflow-role"
  assume_role_policy = local.states_assume
}
resource "aws_iam_role" "task" {
  name               = "${local.name}-task-role"
  assume_role_policy = local.task_assume
}
resource "aws_iam_role" "task_execution" {
  name               = "${local.name}-task-execution-role"
  assume_role_policy = local.task_assume
}
resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role_policy" "request_send" {
  name   = "${local.name}-send"
  role   = aws_iam_role.request.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["sqs:SendMessage"], Resource = aws_sqs_queue.jobs.arn }] })
}
resource "aws_iam_role_policy" "dispatcher_start" {
  name   = "${local.name}-start"
  role   = aws_iam_role.dispatcher.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["states:StartExecution"], Resource = aws_sfn_state_machine.workflow.arn }, { Effect = "Allow", Action = ["dynamodb:PutItem"], Resource = aws_dynamodb_table.jobs.arn }] })
}
resource "aws_iam_role_policy" "workflow_ecs" {
  name = "${local.name}-run-ecs"
  role = aws_iam_role.workflow.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = ["ecs:RunTask"]
        Resource  = aws_ecs_task_definition.processor.arn
        Condition = { ArnEquals = { "ecs:cluster" = aws_ecs_cluster.jobs.arn } }
      },
      {
        Effect    = "Allow"
        Action    = ["ecs:DescribeTasks", "ecs:StopTask"]
        Resource  = "*"
        Condition = { ArnEquals = { "ecs:cluster" = aws_ecs_cluster.jobs.arn } }
      },
      {
        Effect    = "Allow"
        Action    = ["iam:PassRole"]
        Resource  = [aws_iam_role.task.arn, aws_iam_role.task_execution.arn]
        Condition = { StringEquals = { "iam:PassedToService" = "ecs-tasks.amazonaws.com" } }
      },
      {
        Effect   = "Allow"
        Action   = ["events:PutTargets", "events:PutRule", "events:DescribeRule"]
        Resource = "arn:aws:events:us-east-1:${split(":", aws_ecs_cluster.jobs.arn)[4]}:rule/StepFunctionsGetEventsForECSTaskRule"
      }
    ]
  })
}
resource "aws_lambda_function" "request" {
  function_name    = "${local.name}-request"
  role             = aws_iam_role.request.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  filename         = "${path.module}/../../dist/request.zip"
  source_code_hash = filebase64sha256("${path.module}/../../dist/request.zip")
  environment { variables = { QUEUE_URL = aws_sqs_queue.jobs.url } }
}
resource "aws_lambda_function" "dispatcher" {
  function_name    = "${local.name}-dispatcher"
  role             = aws_iam_role.dispatcher.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  filename         = "${path.module}/../../dist/dispatcher.zip"
  source_code_hash = filebase64sha256("${path.module}/../../dist/dispatcher.zip")
  environment { variables = { STATE_MACHINE_ARN = aws_sfn_state_machine.workflow.arn, TABLE_NAME = aws_dynamodb_table.jobs.name } }
}
resource "aws_iam_role_policy" "dispatcher_sqs" {
  name = "${local.name}-dispatcher-queue-consume"
  role = aws_iam_role.dispatcher.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
      Resource = aws_sqs_queue.jobs.arn
    }]
  })
}

resource "aws_lambda_event_source_mapping" "jobs" {
  depends_on       = [aws_iam_role_policy.dispatcher_sqs, aws_iam_role_policy.dispatcher_start]
  event_source_arn = aws_sqs_queue.jobs.arn
  function_name    = aws_lambda_function.dispatcher.arn
}
resource "aws_vpc" "task" {
  cidr_block = "10.80.0.0/16"
}
resource "aws_subnet" "task" {
  vpc_id            = aws_vpc.task.id
  cidr_block        = "10.80.1.0/24"
  availability_zone = "us-east-1a"
}
resource "aws_internet_gateway" "task" {
  vpc_id = aws_vpc.task.id
}
resource "aws_route_table" "task" {
  vpc_id = aws_vpc.task.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.task.id
  }
}
resource "aws_route_table_association" "task" {
  subnet_id      = aws_subnet.task.id
  route_table_id = aws_route_table.task.id
}
resource "aws_security_group" "task" {
  name        = "${local.name}-task"
  description = "No ingress; outbound access for the public container image."
  vpc_id      = aws_vpc.task.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_ecs_cluster" "jobs" { name = "${local.name}-cluster" }
resource "aws_ecs_task_definition" "processor" {
  family                   = "${local.name}-processor"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  task_role_arn            = aws_iam_role.task.arn
  execution_role_arn       = aws_iam_role.task_execution.arn
  depends_on               = [aws_iam_role_policy_attachment.task_execution]
  container_definitions    = jsonencode([{ name = "processor", image = "public.ecr.aws/docker/library/alpine:3.20", essential = true, command = ["/bin/sh", "-c", "echo job; sleep 1"] }])
}
resource "aws_sfn_state_machine" "workflow" {
  name       = "${local.name}-workflow"
  type       = "STANDARD"
  role_arn   = aws_iam_role.workflow.arn
  depends_on = [aws_iam_role_policy.workflow_ecs, aws_route_table_association.task]
  definition = jsonencode({
    StartAt = "RunProcessor"
    States = {
      RunProcessor = {
        Type     = "Task"
        Resource = "arn:aws:states:::ecs:runTask.sync"
        Parameters = {
          LaunchType     = "FARGATE"
          Cluster        = aws_ecs_cluster.jobs.arn
          TaskDefinition = aws_ecs_task_definition.processor.arn
          NetworkConfiguration = {
            AwsvpcConfiguration = {
              Subnets        = [aws_subnet.task.id]
              SecurityGroups = [aws_security_group.task.id]
              AssignPublicIp = "ENABLED"
            }
          }
        }
        End = true
      }
    }
  })
}
resource "aws_api_gateway_rest_api" "jobs" { name = "${local.name}-api" }
resource "aws_api_gateway_resource" "jobs" {
  rest_api_id = aws_api_gateway_rest_api.jobs.id
  parent_id   = aws_api_gateway_rest_api.jobs.root_resource_id
  path_part   = "jobs"
}
resource "aws_api_gateway_method" "post" {
  rest_api_id   = aws_api_gateway_rest_api.jobs.id
  resource_id   = aws_api_gateway_resource.jobs.id
  http_method   = "POST"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "post" {
  rest_api_id             = aws_api_gateway_rest_api.jobs.id
  resource_id             = aws_api_gateway_resource.jobs.id
  http_method             = aws_api_gateway_method.post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.request.invoke_arn
  timeout_milliseconds    = 50
  lifecycle { ignore_changes = [timeout_milliseconds] }
}
resource "aws_lambda_permission" "api" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.request.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.jobs.execution_arn}/*/*"
}
resource "aws_api_gateway_deployment" "jobs" {
  rest_api_id = aws_api_gateway_rest_api.jobs.id
  triggers    = { redeployment = sha1(jsonencode([aws_api_gateway_resource.jobs.id, aws_api_gateway_method.post.id, aws_api_gateway_integration.post.id])) }
  lifecycle { create_before_destroy = true }
}
resource "aws_api_gateway_stage" "local" {
  rest_api_id   = aws_api_gateway_rest_api.jobs.id
  deployment_id = aws_api_gateway_deployment.jobs.id
  stage_name    = "local"
}
