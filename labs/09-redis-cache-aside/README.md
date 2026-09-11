# Lab 09: Lambda → ElastiCache/Redis → DynamoDB

This lab implements cache-aside reads. `POST /notes` writes DynamoDB; the first `GET /notes/{id}` reads DynamoDB and sets a 60-second Redis entry; later reads return the cached note.

```bash
make deploy LAB=09-redis-cache-aside
make test LAB=09-redis-cache-aside
```
