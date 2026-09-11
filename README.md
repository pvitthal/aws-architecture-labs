# AWS Architecture Lab

Runnable AWS architecture patterns, exercised locally with OpenTofu and [Floci](https://floci.io/). No AWS account or cloud resources are used.

## Current labs

| Lab | Pattern | Status |
| --- | --- | --- |
| 01 | API Gateway → Lambda → DynamoDB | Ready for local validation |
| 02 | API Gateway → Lambda → SQS → worker Lambda | Scaffolded; begins after Lab 01 is verified |
| 03 | SQS retries and DLQ | Planned |
| 04 | SNS to SQS fan-out | Planned |
| 05 | S3 to EventBridge to Lambda | Planned |

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

