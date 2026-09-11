# Lab 04 architecture

```text
Client → API Gateway → publisher Lambda → SNS topic
                                          ├─ SQS email queue → email Lambda → email table
                                          └─ SQS audit queue → audit Lambda → audit table
```

SNS fan-out isolates consumers: each queue retains and retries its own delivery without blocking the other. The topic subscriptions request raw message delivery so each worker receives the original notification JSON directly, rather than an SNS envelope.

As with the preceding API Gateway labs, the local workflow reconciles Floci’s API Gateway timeout state before applying. IAM and queue policies are included so the infrastructure shape remains meaningful when moved to AWS.
