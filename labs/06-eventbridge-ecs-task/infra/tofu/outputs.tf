output "cluster_name" { value = aws_ecs_cluster.tasks.name }
output "event_bus_name" { value = "default" }
output "task_family" { value = aws_ecs_task_definition.worker.family }
