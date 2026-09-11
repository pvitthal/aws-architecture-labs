locals {
  name = "lab01-notes"
}

resource "aws_dynamodb_table" "notes" {
  name         = "${local.name}-notes"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_iam_role" "lambda" {
  name = "${local.name}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "dynamodb" {
  name = "${local.name}-dynamodb-write"
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:PutItem"]
      Resource = aws_dynamodb_table.notes.arn
    }]
  })
}

resource "aws_lambda_function" "api" {
  function_name    = "${local.name}-api"
  role             = aws_iam_role.lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  filename         = "${path.module}/../../dist/function.zip"
  source_code_hash = filebase64sha256("${path.module}/../../dist/function.zip")
  timeout          = 10

  environment {
    variables = { TABLE_NAME = aws_dynamodb_table.notes.name }
  }
}

resource "aws_api_gateway_rest_api" "notes" {
  name = "${local.name}-api"
}

resource "aws_api_gateway_resource" "notes" {
  rest_api_id = aws_api_gateway_rest_api.notes.id
  parent_id   = aws_api_gateway_rest_api.notes.root_resource_id
  path_part   = "notes"
}

resource "aws_api_gateway_method" "notes_post" {
  rest_api_id   = aws_api_gateway_rest_api.notes.id
  resource_id   = aws_api_gateway_resource.notes.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "notes_post" {
  rest_api_id             = aws_api_gateway_rest_api.notes.id
  resource_id             = aws_api_gateway_resource.notes.id
  http_method             = aws_api_gateway_method.notes_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.api.invoke_arn
  timeout_milliseconds    = 50

  # Floci currently returns 0 for this API Gateway field and does not support
  # the provider's UpdateIntegration patch for timeoutInMillis.
  lifecycle {
    ignore_changes = [timeout_milliseconds]
  }
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.notes.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "notes" {
  rest_api_id = aws_api_gateway_rest_api.notes.id
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.notes.id,
      aws_api_gateway_method.notes_post.id,
      aws_api_gateway_integration.notes_post.id,
    ]))
  }
  lifecycle { create_before_destroy = true }
}

resource "aws_api_gateway_stage" "local" {
  rest_api_id   = aws_api_gateway_rest_api.notes.id
  deployment_id = aws_api_gateway_deployment.notes.id
  stage_name    = "local"
}
