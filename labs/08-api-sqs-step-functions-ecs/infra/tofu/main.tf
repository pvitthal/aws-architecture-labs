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
  name   = "${local.name}-run-ecs"
  role   = aws_iam_role.workflow.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["ecs:RunTask", "ecs:DescribeTasks", "ecs:StopTask"], Resource = "*" }, { Effect = "Allow", Action = ["iam:PassRole"], Resource = aws_iam_role.task.arn }] })
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
resource "aws_lambda_event_source_mapping" "jobs" {
  event_source_arn = aws_sqs_queue.jobs.arn
  function_name    = aws_lambda_function.dispatcher.arn
}
resource "aws_ecs_cluster" "jobs" { name = "${local.name}-cluster" }
resource "aws_ecs_task_definition" "processor" {
  family                   = "${local.name}-processor"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  task_role_arn            = aws_iam_role.task.arn
  execution_role_arn       = aws_iam_role.task.arn
  container_definitions    = jsonencode([{ name = "processor", image = "public.ecr.aws/docker/library/alpine:3.20", essential = true, command = ["/bin/sh", "-c", "echo job; sleep 1"] }])
}
resource "aws_sfn_state_machine" "workflow" {
  name       = "${local.name}-workflow"
  type       = "STANDARD"
  role_arn   = aws_iam_role.workflow.arn
  definition = jsonencode({ StartAt = "RunProcessor", States = { RunProcessor = { Type = "Task", Resource = "arn:aws:states:::ecs:runTask.sync", Parameters = { LaunchType = "FARGATE", Cluster = aws_ecs_cluster.jobs.arn, TaskDefinition = aws_ecs_task_definition.processor.arn }, End = true } } })
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
}
resource "aws_api_gateway_stage" "local" {
  rest_api_id   = aws_api_gateway_rest_api.jobs.id
  deployment_id = aws_api_gateway_deployment.jobs.id
  stage_name    = "local"
}
