# Lab 09 architecture

```text
Client → API Gateway → Lambda → Redis cache → DynamoDB fallback
```

The test verifies both the database fallback and cache-hit path. In Floci, a single-node replication group reports its usable endpoint through `configuration_endpoint_address`; the lab uses that endpoint instead of AWS's nullable `primary_endpoint_address`.
