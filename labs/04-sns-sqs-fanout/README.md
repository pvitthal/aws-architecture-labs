# Lab 04: SNS → multiple SQS queues

`POST /notifications` publishes one validated notification to SNS. SNS delivers a raw copy to each SQS queue; independent Lambda consumers persist an `email` and an `audit` projection in separate DynamoDB tables.

```bash
make deploy LAB=04-sns-sqs-fanout
make test LAB=04-sns-sqs-fanout
```

The integration test confirms both consumers receive the same notification and checks `400` input validation plus an unknown-route `404`.
