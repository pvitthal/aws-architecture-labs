# Lab 01: API Gateway → Lambda → DynamoDB

This lab exposes `POST /notes`. It validates a JSON `note`, persists it in DynamoDB, and returns the created note.

## Run

```bash
make deploy LAB=01-api-lambda-dynamodb
make test LAB=01-api-lambda-dynamodb
```

## Expected contract

- `POST /notes` with `{ "note": "hello" }` returns `201`, an ID, and persists the item in DynamoDB.
- Invalid JSON and missing/blank `note` return `400`.
- An unknown route returns `404`.

See [observed behavior](architecture.md) after validating with the installed Floci version.
