import { randomUUID } from 'node:crypto';

export const handler = async (event) => {
  const records = event.detail?.records ?? event.Records ?? [];
  const record = records[0] ?? event.detail ?? {};
  const bucket = record.bucket?.name ?? event.detail?.bucket?.name ?? 'unknown';
  const key = record.object?.key ?? event.detail?.object?.key ?? 'unknown';

  const { DynamoDBClient, PutItemCommand } = await import('@aws-sdk/client-dynamodb');
  await new DynamoDBClient({}).send(new PutItemCommand({
    TableName: process.env.TABLE_NAME,
    Item: {
      id: { S: randomUUID() },
      bucket: { S: bucket },
      key: { S: key },
      source: { S: event.source ?? 'aws.s3' },
      eventType: { S: event['detail-type'] ?? 'Object Created' },
    },
  }));
};
