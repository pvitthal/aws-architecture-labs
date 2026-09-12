locals {
  name                      = "lab04-fanout"
  lambda_assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_sns_topic" "notifications" { name = "${local.name}-notifications" }
resource "aws_sqs_queue" "email" { name = "${local.name}-email-queue" }
resource "aws_sqs_queue" "audit" { name = "${local.name}-audit-queue" }
resource "aws_sqs_queue_policy" "email" {
  queue_url = aws_sqs_queue.email.id
  policy    = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "sns.amazonaws.com" }, Action = "sqs:SendMessage", Resource = aws_sqs_queue.email.arn, Condition = { ArnEquals = { "aws:SourceArn" = aws_sns_topic.notifications.arn } } }] })
}
resource "aws_sqs_queue_policy" "audit" {
  queue_url = aws_sqs_queue.audit.id
  policy    = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "sns.amazonaws.com" }, Action = "sqs:SendMessage", Resource = aws_sqs_queue.audit.arn, Condition = { ArnEquals = { "aws:SourceArn" = aws_sns_topic.notifications.arn } } }] })
}
resource "aws_sns_topic_subscription" "email" {
  topic_arn            = aws_sns_topic.notifications.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.email.arn
  raw_message_delivery = true
  depends_on           = [aws_sqs_queue_policy.email]
}
resource "aws_sns_topic_subscription" "audit" {
  topic_arn            = aws_sns_topic.notifications.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.audit.arn
  raw_message_delivery = true
  depends_on           = [aws_sqs_queue_policy.audit]
}
resource "aws_dynamodb_table" "email" {
  name         = "${local.name}-email"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute {
    name = "id"
    type = "S"
  }
}
resource "aws_dynamodb_table" "audit" {
  name         = "${local.name}-audit"
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
resource "aws_iam_role" "email" {
  name               = "${local.name}-email-role"
  assume_role_policy = local.lambda_assume_role_policy
}
resource "aws_iam_role" "audit" {
  name               = "${local.name}-audit-role"
  assume_role_policy = local.lambda_assume_role_policy
}
resource "aws_iam_role_policy" "request_sns" {
  name   = "${local.name}-publish"
  role   = aws_iam_role.request.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["sns:Publish"], Resource = aws_sns_topic.notifications.arn }] })
}
resource "aws_iam_role_policy" "email_table" {
  name   = "${local.name}-email-write"
  role   = aws_iam_role.email.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["dynamodb:PutItem"], Resource = aws_dynamodb_table.email.arn }] })
}
resource "aws_iam_role_policy" "audit_table" {
  name   = "${local.name}-audit-write"
  role   = aws_iam_role.audit.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["dynamodb:PutItem"], Resource = aws_dynamodb_table.audit.arn }] })
}
resource "aws_lambda_function" "request" {
  function_name    = "${local.name}-request"
  role             = aws_iam_role.request.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  filename         = "${path.module}/../../dist/request.zip"
  source_code_hash = filebase64sha256("${path.module}/../../dist/request.zip")
  timeout          = 10
  environment { variables = { TOPIC_ARN = aws_sns_topic.notifications.arn } }
}
resource "aws_lambda_function" "email" {
  function_name    = "${local.name}-email"
  role             = aws_iam_role.email.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  filename         = "${path.module}/../../dist/email-worker.zip"
  source_code_hash = filebase64sha256("${path.module}/../../dist/email-worker.zip")
  timeout          = 10
  environment { variables = { TABLE_NAME = aws_dynamodb_table.email.name } }
}
resource "aws_lambda_function" "audit" {
  function_name    = "${local.name}-audit"
  role             = aws_iam_role.audit.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  filename         = "${path.module}/../../dist/audit-worker.zip"
  source_code_hash = filebase64sha256("${path.module}/../../dist/audit-worker.zip")
  timeout          = 10
  environment { variables = { TABLE_NAME = aws_dynamodb_table.audit.name } }
}
resource "aws_iam_role_policy" "email_sqs" {
  name = "${local.name}-email-queue-consume"
  role = aws_iam_role.email.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
      Resource = aws_sqs_queue.email.arn
    }]
  })
}

resource "aws_lambda_event_source_mapping" "email" {
  depends_on       = [aws_iam_role_policy.email_sqs, aws_iam_role_policy.email_table]
  event_source_arn = aws_sqs_queue.email.arn
  function_name    = aws_lambda_function.email.arn
  batch_size       = 1
}
resource "aws_iam_role_policy" "audit_sqs" {
  name = "${local.name}-audit-queue-consume"
  role = aws_iam_role.audit.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
      Resource = aws_sqs_queue.audit.arn
    }]
  })
}

resource "aws_lambda_event_source_mapping" "audit" {
  depends_on       = [aws_iam_role_policy.audit_sqs, aws_iam_role_policy.audit_table]
  event_source_arn = aws_sqs_queue.audit.arn
  function_name    = aws_lambda_function.audit.arn
  batch_size       = 1
}
resource "aws_api_gateway_rest_api" "notifications" { name = "${local.name}-api" }
resource "aws_api_gateway_resource" "notifications" {
  rest_api_id = aws_api_gateway_rest_api.notifications.id
  parent_id   = aws_api_gateway_rest_api.notifications.root_resource_id
  path_part   = "notifications"
}
resource "aws_api_gateway_method" "notifications_post" {
  rest_api_id   = aws_api_gateway_rest_api.notifications.id
  resource_id   = aws_api_gateway_resource.notifications.id
  http_method   = "POST"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "notifications_post" {
  rest_api_id             = aws_api_gateway_rest_api.notifications.id
  resource_id             = aws_api_gateway_resource.notifications.id
  http_method             = aws_api_gateway_method.notifications_post.http_method
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
  source_arn    = "${aws_api_gateway_rest_api.notifications.execution_arn}/*/*"
}
resource "aws_api_gateway_deployment" "notifications" {
  rest_api_id = aws_api_gateway_rest_api.notifications.id
  triggers    = { redeployment = sha1(jsonencode([aws_api_gateway_resource.notifications.id, aws_api_gateway_method.notifications_post.id, aws_api_gateway_integration.notifications_post.id])) }
  lifecycle { create_before_destroy = true }
}
resource "aws_api_gateway_stage" "local" {
  rest_api_id   = aws_api_gateway_rest_api.notifications.id
  deployment_id = aws_api_gateway_deployment.notifications.id
  stage_name    = "local"
}
