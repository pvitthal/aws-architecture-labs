# Lab 02 architecture

```text
Client → API Gateway → request Lambda → SQS → worker Lambda → DynamoDB
```

## Architectural intent

The API’s responsibility ends after durable queue acceptance, which decouples request latency from processing. The worker must make writes idempotent by using the job ID as the DynamoDB primary key. Lab 03 will add retry, visibility timeout, and DLQ behavior; Lab 02 focuses only on the happy asynchronous handoff and input validation.

