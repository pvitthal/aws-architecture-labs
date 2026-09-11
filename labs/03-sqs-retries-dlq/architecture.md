# Lab 03 architecture

```text
Client → API Gateway → request Lambda → SQS → worker Lambda → DynamoDB
                                             └─ failed twice → DLQ
```

The queue has a five-second visibility timeout and `maxReceiveCount` of two. The worker’s controlled failure is intentional: it verifies redrive behavior without relying on an intermittent dependency. In production, make consumers idempotent because a message may be delivered more than once.

Floci Lambda containers need `localhost.floci.io` for a queue URL returned as `localhost`; the request Lambda normalizes that host. API Gateway timeout state is reconciled by the shared local workflow before planning or applying.
