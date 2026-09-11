# AWS Architecture Lab

Runnable AWS architecture patterns, exercised locally with OpenTofu and [Floci](https://floci.io/). No AWS account or cloud resources are used.

## Current labs

| Lab | Pattern | Status |
| --- | --- | --- |
| 01 | API Gateway → Lambda → DynamoDB | Verified locally |
| 02 | API Gateway → Lambda → SQS → worker Lambda | Verified locally |
| 03 | SQS retries and DLQ | Ready for coordinated validation |
| 04 | SNS to SQS fan-out | Ready for coordinated validation |
| 05 | S3 → EventBridge → Lambda | Ready for coordinated validation |
| 06 | EventBridge → ECS task | Ready for coordinated validation |
| 07 | Step Functions retry/catch → Lambda | Ready for coordinated validation |
| 08 | API → SQS → Step Functions → ECS | Ready for coordinated validation |
| 09 | Lambda → Redis cache-aside → DynamoDB | Verified locally |
| 10 | Event-driven order processing | Ready for coordinated validation |

Every lab includes an `architecture.md` with a rendered Markdown AWS-flow diagram, design notes, and compatibility observations.

## Prerequisites

- Docker Desktop with its daemon running
- OpenTofu
- `curl`, `zip`, and Node.js 20+

## Quick start

```bash
make doctor
make deploy LAB=01-api-lambda-dynamodb
make test LAB=01-api-lambda-dynamodb
```

Use `make destroy LAB=01-api-lambda-dynamodb` when finished. The lab documentation records emulator-specific observations rather than treating them as AWS guarantees.
