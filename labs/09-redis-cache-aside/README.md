# Lab 09: Lambda → ElastiCache/Redis → DynamoDB

This lab implements cache-aside reads. `POST /notes` writes DynamoDB; the first `GET /notes/{id}` reads DynamoDB and sets a 60-second Redis entry; later reads return the cached note.

Redis errors and malformed entries fall back to DynamoDB; cache-fill errors do not fail a successful database read. See the [architecture diagram and compatibility notes](architecture.md).

```bash
make deploy LAB=09-redis-cache-aside
make test LAB=09-redis-cache-aside
node --test labs/09-redis-cache-aside/tests/unit/redis.test.mjs
```
