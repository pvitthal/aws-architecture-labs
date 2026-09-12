locals {
  name = "lab10-orders"
  lambda_assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_sqs_queue" "orders" {
  name                       = "${local.name}-queue"
  visibility_timeout_seconds = 30
}

resource "aws_dynamodb_table" "orders" {
  name         = "${local.name}-orders"
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
  hash_key     = "orderId"
  attribute {
    name = "orderId"
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
resource "aws_iam_role" "audit" {
  name               = "${local.name}-audit-role"
  assume_role_policy = local.lambda_assume_role_policy
}

resource "aws_iam_role_policy" "request_sqs" {
  name   = "${local.name}-queue-send"
  role   = aws_iam_role.request.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["sqs:SendMessage"], Resource = aws_sqs_queue.orders.arn }] })
}
resource "aws_iam_role_policy" "worker_order_and_event" {
  name = "${local.name}-complete-and-publish"
  role = aws_iam_role.worker.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["dynamodb:PutItem"], Resource = aws_dynamodb_table.orders.arn },
    { Effect = "Allow", Action = ["events:PutEvents"], Resource = "*" },
  ] })
}
resource "aws_iam_role_policy" "audit_write" {
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
  environment { variables = { QUEUE_URL = aws_sqs_queue.orders.url } }
}
resource "aws_lambda_function" "worker" {
  function_name    = "${local.name}-worker"
  role             = aws_iam_role.worker.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  filename         = "${path.module}/../../dist/worker.zip"
  source_code_hash = filebase64sha256("${path.module}/../../dist/worker.zip")
  timeout          = 10
  environment { variables = { ORDERS_TABLE_NAME = aws_dynamodb_table.orders.name } }
}
resource "aws_lambda_function" "audit" {
  function_name    = "${local.name}-audit"
  role             = aws_iam_role.audit.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  filename         = "${path.module}/../../dist/audit.zip"
  source_code_hash = filebase64sha256("${path.module}/../../dist/audit.zip")
  timeout          = 10
  environment { variables = { AUDIT_TABLE_NAME = aws_dynamodb_table.audit.name } }
}
resource "aws_iam_role_policy" "worker_sqs" {
  name = "${local.name}-worker-queue-consume"
  role = aws_iam_role.worker.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
      Resource = aws_sqs_queue.orders.arn
    }]
  })
}

resource "aws_lambda_event_source_mapping" "orders" {
  depends_on       = [aws_iam_role_policy.worker_sqs, aws_iam_role_policy.worker_order_and_event]
  event_source_arn = aws_sqs_queue.orders.arn
  function_name    = aws_lambda_function.worker.arn
  batch_size       = 1
}

resource "aws_cloudwatch_event_rule" "order_completed" {
  name          = "${local.name}-completed"
  event_pattern = jsonencode({ source = ["lab.orders"], "detail-type" = ["order.completed"] })
}
resource "aws_cloudwatch_event_target" "audit" {
  rule = aws_cloudwatch_event_rule.order_completed.name
  arn  = aws_lambda_function.audit.arn
}
resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeAuditInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.audit.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.order_completed.arn
}

resource "aws_api_gateway_rest_api" "orders" { name = "${local.name}-api" }
resource "aws_api_gateway_resource" "orders" {
  rest_api_id = aws_api_gateway_rest_api.orders.id
  parent_id   = aws_api_gateway_rest_api.orders.root_resource_id
  path_part   = "orders"
}
resource "aws_api_gateway_method" "orders_post" {
  rest_api_id   = aws_api_gateway_rest_api.orders.id
  resource_id   = aws_api_gateway_resource.orders.id
  http_method   = "POST"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "orders_post" {
  rest_api_id             = aws_api_gateway_rest_api.orders.id
  resource_id             = aws_api_gateway_resource.orders.id
  http_method             = aws_api_gateway_method.orders_post.http_method
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
  source_arn    = "${aws_api_gateway_rest_api.orders.execution_arn}/*/*"
}
resource "aws_api_gateway_deployment" "orders" {
  rest_api_id = aws_api_gateway_rest_api.orders.id
  triggers    = { redeployment = sha1(jsonencode([aws_api_gateway_resource.orders.id, aws_api_gateway_method.orders_post.id, aws_api_gateway_integration.orders_post.id])) }
  lifecycle { create_before_destroy = true }
}
resource "aws_api_gateway_stage" "local" {
  rest_api_id   = aws_api_gateway_rest_api.orders.id
  deployment_id = aws_api_gateway_deployment.orders.id
  stage_name    = "local"
}
