# Lab 06 architecture and validation boundary

```text
Producer → EventBridge default bus → matching rule → ECS RunTask (Fargate) → short-lived container
                                      │
                                      └→ EventBridge IAM role → ECS task definition / execution role
```

## Intended AWS behavior

An event whose source is `lab.architecture` and detail type is `run-task` matches the EventBridge rule. EventBridge assumes the narrowly scoped role and calls `ecs:RunTask` for the Fargate-compatible task definition. The task runs in the lab VPC subnet without public IP assignment, writes its startup marker, and exits successfully.

## Local test contract

The integration test publishes a matching EventBridge event and polls ECS for a stopped task. It confirms an event was accepted, a task was created, and the expected task family reached `STOPPED`. It does not claim that Floci reproduces AWS networking, Fargate scheduling, image-pull behavior, CloudWatch logging, or IAM enforcement.

## Coordinated-validation observations to record

- Whether Floci supports EventBridge ECS targets with `FARGATE` and `awsvpc` network configuration.
- Whether the selected public image can be pulled by Floci's Docker runtime.
- Whether the task's exit status and stopped reason are exposed through the ECS emulator.

If any of these are unsupported, retain the OpenTofu architecture and mark the local test as unsupported rather than replacing it with a direct `RunTask` test: direct invocation would no longer verify the EventBridge target boundary. Run the same test in an AWS sandbox before production use.
