locals {
  name                      = "lab03-retries"
  lambda_assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_sqs_queue" "dlq" { name = "${local.name}-dlq" }
resource "aws_sqs_queue" "jobs" {
  name                       = "${local.name}-queue"
  visibility_timeout_seconds = 60
  redrive_policy             = jsonencode({ deadLetterTargetArn = aws_sqs_queue.dlq.arn, maxReceiveCount = 2 })
}
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
  assume_role_policy = local.lambda_assume_role_policy
}
resource "aws_iam_role" "worker" {
  name               = "${local.name}-worker-role"
  assume_role_policy = local.lambda_assume_role_policy
}
resource "aws_iam_role_policy" "request_sqs" {
  name   = "${local.name}-queue-send"
  role   = aws_iam_role.request.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["sqs:SendMessage"], Resource = aws_sqs_queue.jobs.arn }] })
}
resource "aws_iam_role_policy" "worker_table" {
  name   = "${local.name}-table-write"
  role   = aws_iam_role.worker.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["dynamodb:PutItem"], Resource = aws_dynamodb_table.jobs.arn }] })
}
resource "aws_lambda_function" "request" {
  function_name    = "${local.name}-request"
  role             = aws_iam_role.request.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  filename         = "${path.module}/../../dist/request.zip"
  source_code_hash = filebase64sha256("${path.module}/../../dist/request.zip")
  timeout          = 10
  environment { variables = { QUEUE_URL = aws_sqs_queue.jobs.url } }
}
resource "aws_lambda_function" "worker" {
  function_name    = "${local.name}-worker"
  role             = aws_iam_role.worker.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  filename         = "${path.module}/../../dist/worker.zip"
  source_code_hash = filebase64sha256("${path.module}/../../dist/worker.zip")
  timeout          = 10
  environment { variables = { TABLE_NAME = aws_dynamodb_table.jobs.name } }
}
resource "aws_iam_role_policy" "worker_sqs" {
  name = "${local.name}-worker-queue-consume"
  role = aws_iam_role.worker.id
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
  depends_on       = [aws_iam_role_policy.worker_sqs, aws_iam_role_policy.worker_table]
  event_source_arn = aws_sqs_queue.jobs.arn
  function_name    = aws_lambda_function.worker.arn
  batch_size       = 1
}
resource "aws_api_gateway_rest_api" "jobs" { name = "${local.name}-api" }
resource "aws_api_gateway_resource" "jobs" {
  rest_api_id = aws_api_gateway_rest_api.jobs.id
  parent_id   = aws_api_gateway_rest_api.jobs.root_resource_id
  path_part   = "jobs"
}
resource "aws_api_gateway_method" "jobs_post" {
  rest_api_id   = aws_api_gateway_rest_api.jobs.id
  resource_id   = aws_api_gateway_resource.jobs.id
  http_method   = "POST"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "jobs_post" {
  rest_api_id             = aws_api_gateway_rest_api.jobs.id
  resource_id             = aws_api_gateway_resource.jobs.id
  http_method             = aws_api_gateway_method.jobs_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.request.invoke_arn
  timeout_milliseconds    = 50
  lifecycle { ignore_changes = [timeout_milliseconds] }
}
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.request.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.jobs.execution_arn}/*/*"
}
resource "aws_api_gateway_deployment" "jobs" {
  rest_api_id = aws_api_gateway_rest_api.jobs.id
  triggers    = { redeployment = sha1(jsonencode([aws_api_gateway_resource.jobs.id, aws_api_gateway_method.jobs_post.id, aws_api_gateway_integration.jobs_post.id])) }
  lifecycle { create_before_destroy = true }
}
resource "aws_api_gateway_stage" "local" {
  rest_api_id   = aws_api_gateway_rest_api.jobs.id
  deployment_id = aws_api_gateway_deployment.jobs.id
  stage_name    = "local"
}
