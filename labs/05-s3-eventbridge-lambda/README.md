# Lab 05: S3 → EventBridge → Lambda

Lab 05 models an object-created processing pipeline. S3 is configured to publish to EventBridge; an EventBridge rule filters object-created events for the lab bucket and invokes a Lambda that records the bucket and key in DynamoDB.

## Run

```bash
make deploy LAB=05-s3-eventbridge-lambda
make test LAB=05-s3-eventbridge-lambda
```

## Test boundary

The integration test uploads a real S3 object and waits for its DynamoDB record, covering the S3 notification boundary as well as EventBridge → Lambda → DynamoDB. Deployment and this test passed on Floci 2.0.1 with AWS provider 6.64.0. The test requires curl with AWS SigV4 support and removes its uploaded object afterward. An AWS sandbox run is still needed to establish production behavior.

See [architecture notes](architecture.md) for observed behavior and the production validation checklist.
