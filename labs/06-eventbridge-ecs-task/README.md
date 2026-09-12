# Lab 06: EventBridge → ECS/Fargate task

Lab 06 launches a short-lived Fargate task when a matching EventBridge event reaches the default event bus. It introduces the network configuration, EventBridge invocation role, task execution role, cluster, task definition, and ECS target needed for an event-triggered task.

## Run

```bash
make deploy LAB=06-eventbridge-ecs-task
make test LAB=06-eventbridge-ecs-task
```

The test sends a matching event, then polls ECS until the task has stopped successfully. It uses a short Amazon Linux command that exits with code zero, so successful task completion is observable without depending on an application endpoint.

See [architecture notes](architecture.md) for the emulator validation boundary.

## Verified local limitation

On Floci 2.0.1, infrastructure deployment succeeds, but the integration test fails: EventBridge accepts the event and cannot dispatch the ECS target. The emulator logs an unsupported ECS target ARN. This lab is deployable locally but its native EventBridge → ECS execution is currently unsupported; the test deliberately remains failing until that integration is available.
