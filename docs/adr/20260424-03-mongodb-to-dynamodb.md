# ADR-20260424-03: Migrate from MongoDB to Amazon DynamoDB

## Status
Accepted

## Context
MongoDB runs as a Kubernetes pod with no persistent volume — data is lost on pod restart. This is acceptable for a demo app but not for production. The EKS → Fargate migration removes the MongoDB pod. The team evaluated managed MongoDB options (DocumentDB, Atlas) vs a native AWS NoSQL service.

## Decision
Replace MongoDB with **Amazon DynamoDB**. Replace the Motor/PyMongo async driver with **boto3 DynamoDB resource**. Use separate tables for the three primary entities: `Claims`, `Policies`, `Customers`.

## Consequences

### Pros
- Fully managed — no pod, no backup configuration, no version upgrades
- Serverless pricing (on-demand capacity) — no provisioned throughput to size
- Native IAM integration — task role grants table access, no connection string secret
- DynamoDB integrates directly with CDK table definitions
- TTL support for automatic cleanup of old processed claims

### Cons
- DynamoDB's access patterns must be defined upfront (no ad-hoc queries like MongoDB)
- Nested document queries require GSIs or application-side filtering
- Existing Pydantic models use `PyObjectId` (BSON) — must be replaced with string UUIDs
- No MongoDB aggregation pipeline — complex analytics queries need redesign

### Maintenance
- `database_models.py` rewritten: Motor → boto3, ObjectId → UUID, nested docs → flat attributes + JSON strings where needed
- Table definitions in CDK `DataStack` — schema changes require CDK deploy
- GSIs defined at table creation; adding GSIs later requires table rebuild or new GSI (eventual consistency window)
- All DynamoDB access via ECS task role (IRSA equivalent) — no credentials in code
