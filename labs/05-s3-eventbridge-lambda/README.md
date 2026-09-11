# Lab 05: S3 → EventBridge → Lambda

Lab 05 models an object-created processing pipeline. S3 is configured to publish to EventBridge; an EventBridge rule filters object-created events for the lab bucket and invokes a Lambda that records the bucket and key in DynamoDB.

## Run

```bash
make deploy LAB=05-s3-eventbridge-lambda
TABLE_NAME="$(cd labs/05-s3-eventbridge-lambda/infra/tofu && tofu output -raw table_name)" \
BUCKET_NAME="$(cd labs/05-s3-eventbridge-lambda/infra/tofu && tofu output -raw bucket_name)" \
node labs/05-s3-eventbridge-lambda/tests/integration/eventbridge.test.mjs
```

## Test boundary

The integration test sends a deterministic EventBridge event with the same `source`, `detail-type`, and detail shape targeted by the rule. This reliably verifies the rule → Lambda → DynamoDB portion without treating emulator S3 notification behavior as an AWS guarantee. The infrastructure still enables the production S3 → EventBridge handoff; validate that handoff with an S3 `PutObject` test in an AWS sandbox before release.

See [architecture notes](architecture.md) for observed behavior and the production validation checklist.
