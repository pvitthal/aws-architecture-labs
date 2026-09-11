# Lab 03: SQS retries + dead-letter queue

This lab extends the asynchronous job pattern with a redrive policy. `POST /jobs` accepts `payload` and an optional boolean `fail`. A job with `fail: true` deliberately makes the worker fail; after two receives it is moved to the DLQ. Other jobs are persisted as `completed` in DynamoDB.

```bash
make deploy LAB=03-sqs-retries-dlq
make test LAB=03-sqs-retries-dlq
```

The integration test submits both paths, polls the table and DLQ with a bounded deadline, and checks `400` and `404` responses.
