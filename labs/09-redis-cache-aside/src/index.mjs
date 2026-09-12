import { randomUUID } from 'node:crypto';
import { readThroughCache } from './redis.mjs';

const reply = (statusCode, body) => ({ statusCode, headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) });

const normalize = (event) => event.pathParameters?.id ?? event.rawPath?.split('/').at(-1);

export const handler = async (event) => {
  const { DynamoDBClient, GetItemCommand, PutItemCommand } = await import('@aws-sdk/client-dynamodb');
  const db = new DynamoDBClient({});

  if (event.httpMethod === 'POST') {
    let input;
    try { input = JSON.parse(event.body ?? '{}'); } catch { return reply(400, { error: 'Request body must be valid JSON.' }); }
    if (typeof input.note !== 'string' || !input.note.trim()) return reply(400, { error: 'The "note" field is required.' });
    const note = { id: randomUUID(), note: input.note.trim() };
    await db.send(new PutItemCommand({ TableName: process.env.TABLE_NAME, Item: { id: { S: note.id }, note: { S: note.note } } }));
    return reply(201, note);
  }

  const id = normalize(event);
  if (!id) return reply(400, { error: 'A note ID is required.' });
  const cacheKey = `note:${id}`;
  const note = await readThroughCache(cacheKey, async () => {
    const item = await db.send(new GetItemCommand({ TableName: process.env.TABLE_NAME, Key: { id: { S: id } }, ConsistentRead: true }));
    return item.Item ? { id: item.Item.id.S, note: item.Item.note.S } : null;
  });
  return note ? reply(200, note) : reply(404, { error: 'Note not found.' });
};
