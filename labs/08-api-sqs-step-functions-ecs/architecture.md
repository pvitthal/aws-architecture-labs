# Lab 08 architecture notes

```text
client → API Gateway → request Lambda → SQS → dispatcher Lambda
                                             ├─ writes submitted job + execution ARN to DynamoDB
                                             └─ starts Step Functions → ECS/Fargate task → completed execution
                                                                           └─ task failure → failed execution
```

The API boundary deliberately ends at the SQS acknowledgement. The dispatcher provides durable correlation by storing the Step Functions execution ARN before it returns the SQS message. The workflow waits for the Fargate task through `ecs:runTask.sync`; a task error therefore makes the execution fail and lets the SQS/Lambda retry policy redeliver the request if the dispatcher itself cannot start it.

The supplied task intentionally uses a minimal public Alpine image and a bounded one-second command. It proves orchestration rather than business-container logic. Replace it with an application image and explicit task-level observability for a production workload.

Floci's ECS/Fargate and synchronous Step Functions service-integration support must be checked during the coordinated validation pass. The integration test currently validates acceptance and durable workflow-submission handoff; it should be extended to assert terminal ECS execution state once that capability is confirmed.
