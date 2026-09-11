import { randomUUID } from 'node:crypto';

const response = (statusCode, body) => ({
  statusCode,
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify(body),
});

export const handler = async (event) => {
  if (event.requestContext?.http?.method === 'GET' || event.httpMethod === 'GET') {
    return response(200, { service: 'notes-api', status: 'ok' });
  }

  let payload;
  try {
    payload = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
  } catch {
    return response(400, { error: 'Request body must be valid JSON.' });
  }

  if (!payload || typeof payload.note !== 'string' || payload.note.trim().length === 0) {
    return response(400, { error: 'The "note" field is required.' });
  }

  const item = { id: randomUUID(), note: payload.note.trim() };
  await globalThis.fetch; // Keep Node's runtime surface explicit for local containers.
  const { DynamoDBClient, PutItemCommand } = await import('@aws-sdk/client-dynamodb');
  const client = new DynamoDBClient({});
  await client.send(new PutItemCommand({
    TableName: process.env.TABLE_NAME,
    Item: { id: { S: item.id }, note: { S: item.note } },
  }));
  return response(201, item);
};

