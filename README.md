# AWS Architecture Lab

Runnable AWS architecture patterns, exercised locally with OpenTofu and [Floci](https://floci.io/). No AWS account or cloud resources are used.

## Current labs

| Lab | Pattern | Status |
| --- | --- | --- |
| 01 | API Gateway → Lambda → DynamoDB | Verified locally |
| 02 | API Gateway → Lambda → SQS → worker Lambda | Verified locally |
| 03 | SQS retries and DLQ | Verified locally |
| 04 | SNS to SQS fan-out | Verified locally |
| 05 | S3 → EventBridge → Lambda | Verified locally with real S3 upload |
| 06 | EventBridge → ECS task | Deploys; ECS target dispatch unsupported in Floci 2.0.1 |
| 07 | Step Functions retry/catch → Lambda | Verified locally, including retry count |
| 08 | API → SQS → Step Functions → ECS | Verified locally through ECS exit zero |
| 09 | Lambda → Redis cache-aside → DynamoDB | Verified locally |
| 10 | Event-driven order processing | Verified locally |

Every lab includes an `architecture.md` with a rendered Markdown AWS-flow diagram, design notes, and compatibility observations.

Validation on 2026-09-12 used Floci 2.0.1 and AWS provider 6.64.0. All ten
OpenTofu configurations validate and deploy. Nine integration suites pass;
Lab 06's strict test fails at the documented unsupported dispatch boundary.
The six Redis unit regressions also pass. Labs 01 and 09 additionally produced
no-change plans after refreshing state; Lab 01 retained its resources across a
Floci restart. These results are local emulator observations, not AWS certification.

## Prerequisites

- Docker Desktop with its daemon running
- OpenTofu
- `curl`, `jq`, `zip`, and Node.js 20+

## Quick start

```bash
make doctor
make deploy LAB=01-api-lambda-dynamodb
make test LAB=01-api-lambda-dynamodb
```

Use `make destroy LAB=01-api-lambda-dynamodb` when finished. The lab documentation records emulator-specific observations rather than treating them as AWS guarantees.

## Local state and compatibility

Floci is pinned to version 2.0.1 and configured to persist service state in
`floci-data/`. It listens on localhost only, uses dummy credentials, and mounts
the Docker socket to run local workloads; do not expose it to an untrusted network.
Changing an existing memory-mode container to persistent mode does not migrate
its in-memory resources. Deploy the labs again after that transition.

Before each plan or deployment, the shared workflow refreshes existing local
OpenTofu state. It then normalizes only API Gateway integration timeouts reported
as zero by Floci to the provider's minimum of 50 milliseconds. The immediately
following plan/apply skips a second refresh to avoid reintroducing that emulator
incompatibility. State-read failures stop the workflow. This workaround assumes
local state; it is not a template for remote or production state management.

Each lab's test runner exercises its own entry point and required outputs.
`make clean` preserves provider lockfiles. Local emulator success does not verify
AWS IAM enforcement, networking, quotas, or operational readiness on AWS.
