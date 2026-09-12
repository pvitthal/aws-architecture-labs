# Lab 03 architecture

```mermaid
flowchart LR
  Client --> API
  subgraph Local["Local Floci boundary — AWS service APIs"]
    API[Amazon API Gateway] --> Request[Request Lambda]
    Request --> Queue[Amazon SQS]
    Queue -->|Lambda event source polling| Worker[Worker Lambda]
    Worker -->|Successful processing| DB[(Amazon DynamoDB)]
    Worker -.->|Controlled failure: retry| Queue
    Queue -->|Redrive after receive threshold| DLQ[SQS dead-letter queue]
    Role[IAM consumer role] -.-> Worker
  end
  Request -->|202 accepted or 400 invalid| Client
```

The queue has a 60-second visibility timeout, six times the worker's 10-second timeout, and `maxReceiveCount` of two. The bounded integration poll allows time for visibility expiration and redrive. The worker’s controlled failure is intentional: it verifies redrive behavior without relying on an intermittent dependency. In production, make consumers idempotent because a message may be delivered more than once.

Floci Lambda containers need `localhost.floci.io` for a queue URL returned as `localhost`; the request Lambda normalizes that host. API Gateway timeout state is reconciled by the shared local workflow before planning or applying.
