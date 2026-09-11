# Lab 07 architecture notes

```text
input → Step Functions → processor Lambda → processed result
                       └─ retry once on task failure
                          └─ compensator Lambda → compensated result
```

The retry is deliberately short (one second, two total attempts) so the integration test remains bounded. Production workflows should set retry classes, intervals, and maximum attempts from the downstream service's idempotency and recovery guarantees.

Floci support for the `lambda:invoke` Step Functions service integration must be verified during coordinated deployment. The test uses Step Functions' `StartExecution` and `DescribeExecution` APIs directly, so it validates both the happy and compensation branches without depending on a fixed sleep.
