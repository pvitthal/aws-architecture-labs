# Lab 07: Step Functions → Lambda with retry and catch

Lab 07 makes a failure policy executable. A Standard Step Functions workflow invokes a processor Lambda, retries task failures once, and routes terminal failures to a compensating Lambda with `Catch`.

## Contract

- A valid input succeeds with `{ id, payload, status: "processed" }`.
- `forceFailure: true` deterministically exercises retry then compensation.
- The compensated outcome is a successful workflow result with `status: "compensated"`; the workflow contains the failure rather than exposing a partial operation.

Run locally:

```bash
make deploy LAB=07-step-functions-retry-catch
make test LAB=07-step-functions-retry-catch
```

See [architecture notes](architecture.md) for the state transitions and emulator validation scope.
