locals {
  name                      = "lab07-retry-catch"
  lambda_assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }] })
  states_assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "states.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}

resource "aws_iam_role" "processor" {
  name               = "${local.name}-processor-role"
  assume_role_policy = local.lambda_assume_role_policy
}
resource "aws_iam_role" "compensator" {
  name               = "${local.name}-compensator-role"
  assume_role_policy = local.lambda_assume_role_policy
}
resource "aws_iam_role" "state_machine" {
  name               = "${local.name}-state-machine-role"
  assume_role_policy = local.states_assume_role_policy
}

resource "aws_iam_role_policy" "invoke_lambdas" {
  name   = "${local.name}-invoke-lambdas"
  role   = aws_iam_role.state_machine.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["lambda:InvokeFunction"], Resource = [aws_lambda_function.processor.arn, aws_lambda_function.compensator.arn] }] })
}

resource "aws_lambda_function" "processor" {
  function_name    = "${local.name}-processor"
  role             = aws_iam_role.processor.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  filename         = "${path.module}/../../dist/processor.zip"
  source_code_hash = filebase64sha256("${path.module}/../../dist/processor.zip")
  timeout          = 10
}
resource "aws_lambda_function" "compensator" {
  function_name    = "${local.name}-compensator"
  role             = aws_iam_role.compensator.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  filename         = "${path.module}/../../dist/compensator.zip"
  source_code_hash = filebase64sha256("${path.module}/../../dist/compensator.zip")
  timeout          = 10
}

resource "aws_sfn_state_machine" "workflow" {
  name     = "${local.name}-workflow"
  role_arn = aws_iam_role.state_machine.arn
  type     = "STANDARD"
  definition = jsonencode({
    Comment = "Retries a processor then compensates on a terminal failure"
    StartAt = "Process"
    States = {
      Process = {
        Type           = "Task", Resource = "arn:aws:states:::lambda:invoke"
        Parameters     = { FunctionName = aws_lambda_function.processor.arn, "Payload.$" = "$" }
        ResultSelector = { "id.$" = "$.Payload.id", "payload.$" = "$.Payload.payload", "status.$" = "$.Payload.status" }
        Retry          = [{ ErrorEquals = ["States.TaskFailed"], IntervalSeconds = 1, MaxAttempts = 1, BackoffRate = 1.0 }]
        Catch          = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.error", Next = "Compensate" }]
        End            = true
      }
      Compensate = {
        Type       = "Task", Resource = "arn:aws:states:::lambda:invoke"
        Parameters = { FunctionName = aws_lambda_function.compensator.arn, "Payload.$" = "$" }
        OutputPath = "$.Payload", End = true
      }
    }
  })
}
