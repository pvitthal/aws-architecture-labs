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

Verified on Floci 2.0.1: the integration test follows the submitted execution ARN
through workflow success and verifies its exact ECS task stopped with exit code
zero. Input `400` and unknown-route `404` checks also pass. See
[architecture notes](architecture.md) for the local validation boundary.
