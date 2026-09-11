locals {
  name = "lab05-objects"
  lambda_assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_s3_bucket" "uploads" {
  bucket        = "${local.name}-uploads"
  force_destroy = true
}

resource "aws_s3_bucket_notification" "eventbridge" {
  bucket      = aws_s3_bucket.uploads.id
  eventbridge = true
}

resource "aws_dynamodb_table" "processed" {
  name         = "${local.name}-processed"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_iam_role" "processor" {
  name               = "${local.name}-processor-role"
  assume_role_policy = local.lambda_assume_role_policy
}

resource "aws_iam_role_policy" "processor_dynamodb" {
  name = "${local.name}-table-write"
  role = aws_iam_role.processor.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["dynamodb:PutItem"], Resource = aws_dynamodb_table.processed.arn }]
  })
}

resource "aws_lambda_function" "processor" {
  function_name    = "${local.name}-processor"
  role             = aws_iam_role.processor.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  filename         = "${path.module}/../../dist/processor.zip"
  source_code_hash = filebase64sha256("${path.module}/../../dist/processor.zip")
  timeout          = 10
  environment { variables = { TABLE_NAME = aws_dynamodb_table.processed.name } }
}

resource "aws_cloudwatch_event_rule" "object_created" {
  name        = "${local.name}-object-created"
  description = "Routes S3 object-created events to the processor Lambda."
  event_pattern = jsonencode({
    source        = ["aws.s3"]
    "detail-type" = ["Object Created"]
    detail        = { bucket = { name = [aws_s3_bucket.uploads.bucket] } }
  })
}

resource "aws_cloudwatch_event_target" "processor" {
  rule = aws_cloudwatch_event_rule.object_created.name
  arn  = aws_lambda_function.processor.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.object_created.arn
}
