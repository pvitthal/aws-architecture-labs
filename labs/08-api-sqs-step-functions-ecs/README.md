# Lab 08: API Gateway → SQS → Step Functions → ECS

Lab 08 accepts a long-running job synchronously only up to queue acknowledgement. A dispatcher Lambda consumes the queue, starts a Standard Step Functions execution, and records the execution ARN. The workflow owns the Fargate task lifecycle.

## Contract

- `POST /jobs` returns `202` for a valid payload.
- Input validation failures return `400` and never enqueue a job.
- The dispatcher persists a `submitted` job record including its execution ARN.
- ECS completion is modeled with the synchronous `ecs:runTask.sync` service integration, so workflow completion means the task has stopped.

```bash
make deploy LAB=08-api-sqs-step-functions-ecs
make test LAB=08-api-sqs-step-functions-ecs
```

The ECS integration requires a Floci capability check during coordinated deployment; see [architecture notes](architecture.md).
