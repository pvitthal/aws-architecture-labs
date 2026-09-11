output "bucket_name" { value = aws_s3_bucket.uploads.bucket }
output "table_name" { value = aws_dynamodb_table.processed.name }
output "event_bus_name" { value = "default" }
