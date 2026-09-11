# Lab 10: Event-driven order processing

Lab 10 is an end-to-end asynchronous order pipeline: an API accepts an order, queues it, a worker persists the completed order, and the worker publishes a domain event consumed by an audit Lambda.

```text
Client → API Gateway → request Lambda → SQS → worker Lambda → DynamoDB (orders)
                                                   │
                                                   └→ EventBridge → audit Lambda → DynamoDB (audit)
```

## Run

```bash
make deploy LAB=10-event-driven-order-processing
make test LAB=10-event-driven-order-processing
```

The integration test asserts the `202` API acknowledgement, completed order record, and independent audit record for the same order ID. It also covers invalid input (`400`) and an unknown API route (`404`).

See [architecture notes](architecture.md) for delivery and emulator boundaries.
