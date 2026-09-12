# Lab 04 architecture

```mermaid
flowchart LR
  Client --> API
  subgraph Local["Local Floci boundary — AWS service APIs"]
    API[Amazon API Gateway] --> Publisher[Publisher Lambda]
    Publisher --> SNS[Amazon SNS topic]
    SNS --> EmailQ[SQS email queue]
    SNS --> AuditQ[SQS audit queue]
    EmailQ --> Email[Email Lambda]
    AuditQ --> Audit[Audit Lambda]
    Email --> EmailDB[(DynamoDB email table)]
    Audit --> AuditDB[(DynamoDB audit table)]
    Email -.->|Failure: independent retry| EmailQ
    Audit -.->|Failure: independent retry| AuditQ
    Policy[SNS queue policies and Lambda IAM roles] -.-> EmailQ
    Policy -.-> AuditQ
  end
```

SNS fan-out isolates consumers: each queue retains and retries its own delivery without blocking the other. The topic subscriptions request raw message delivery so each worker receives the original notification JSON directly, rather than an SNS envelope.

Verified on Floci 2.0.1 with AWS provider 6.64.0: deployment and the integration
test pass, including persistence by both independent consumers.

As with the preceding API Gateway labs, the local workflow reconciles Floci’s API Gateway timeout state before applying. IAM and queue policies are included so the infrastructure shape remains meaningful when moved to AWS.
