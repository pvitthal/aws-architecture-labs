# Lab 02: API Gateway → Lambda → SQS → worker Lambda

Lab 02 starts after the verified Lab 01 milestone. It introduces an asynchronous write path: the API acknowledges a valid job with `202`, then a worker Lambda consumes the SQS message and stores the completed job in DynamoDB.

## Intended contract

- `POST /jobs` with a non-empty `payload` responds `202` with a job ID.
- Invalid JSON or a missing/blank `payload` responds `400` and never enqueues work.
- The worker persists the job ID and payload after SQS delivery.
- The integration suite will poll with a bounded timeout rather than relying on a fixed sleep.

## Delivery order

1. Add the OpenTofu resources: REST API, request Lambda, SQS queue, worker Lambda, DynamoDB table, and minimum IAM policies.
2. Package both Node.js functions with a shared build target.
3. Add an end-to-end test for `202` acknowledgement and eventual DynamoDB persistence.
4. Add failure and queue-inspection scenarios before extending it with a DLQ (Lab 03).

Run it locally with:

```bash
make deploy LAB=02-api-sqs-worker
make test LAB=02-api-sqs-worker
```

## Observed behavior

Validated with Floci 2.0.1 and `hashicorp/aws` 6.64.0: API Gateway accepted a job with `202`, SQS invoked the worker Lambda, and the worker persisted the completed job in DynamoDB. The integration suite also verifies `400` input validation and a `404` unknown route.

See [architecture notes](architecture.md) for the two Floci-specific compatibility details.
