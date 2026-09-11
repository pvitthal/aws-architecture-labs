output "api_url" {
  value = "http://localhost:4566/restapis/${aws_api_gateway_rest_api.notes.id}/${aws_api_gateway_stage.local.stage_name}/_user_request_/notes"
}

output "table_name" {
  value = aws_dynamodb_table.notes.name
}

