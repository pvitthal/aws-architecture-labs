output "api_url" { value = "http://localhost:4566/restapis/${aws_api_gateway_rest_api.notifications.id}/${aws_api_gateway_stage.local.stage_name}/_user_request_/notifications" }
output "email_table_name" { value = aws_dynamodb_table.email.name }
output "audit_table_name" { value = aws_dynamodb_table.audit.name }
