# Lab 05 architecture and validation boundary

```text
S3 PutObject → EventBridge default bus → object-created rule → Lambda → DynamoDB
```

## Intended AWS behavior

`aws_s3_bucket_notification` enables EventBridge delivery for the bucket. AWS emits S3 Object Created events on the default bus; the rule limits delivery to this bucket and invokes the processor Lambda.

## What the local integration test proves

The test uses `PutEvents` to send a synthetic `aws.s3` / `Object Created` event that matches the rule. It then polls DynamoDB for the bucket and generated object key. That is deliberately a reliable EventBridge target-delivery test, not a claim that Floci emitted the original S3 notification.

## What must be observed during coordinated validation

- Whether Floci accepts the bucket EventBridge notification configuration.
- Whether a real local `PutObject` causes an EventBridge event and invokes the Lambda.
- The exact Floci and AWS provider versions used.

Until those observations are recorded, S3-origin delivery is **unverified locally**. Production release still requires an AWS-sandbox test that uploads an object, waits for the DynamoDB row, and verifies least-privilege IAM (the local emulator does not provide sufficient IAM-enforcement coverage).
