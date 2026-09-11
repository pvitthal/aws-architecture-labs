# Lab 06: EventBridge → ECS/Fargate task

Lab 06 launches a short-lived Fargate task when a matching EventBridge event reaches the default event bus. It introduces the network configuration, EventBridge invocation role, task execution role, cluster, task definition, and ECS target needed for an event-triggered task.

## Run

```bash
make deploy LAB=06-eventbridge-ecs-task
make test LAB=06-eventbridge-ecs-task
```

The test sends a matching event, then polls ECS until the task has stopped successfully. It uses a short Amazon Linux command that exits with code zero, so successful task completion is observable without depending on an application endpoint.

See [architecture notes](architecture.md) for the emulator validation boundary.
