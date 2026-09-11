import { randomUUID } from 'node:crypto';
import net from 'node:net';

const reply = (statusCode, body) => ({ statusCode, headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) });

const redisCommand = (command) => new Promise((resolve, reject) => {
  const [host, port = '6379'] = process.env.REDIS_ENDPOINT.split(':');
  const socket = net.createConnection({ host, port: Number(port) });
  let data = '';
  socket.setTimeout(2_000);
  socket.on('connect', () => socket.write(`*${command.length}\r\n${command.map((part) => `$${Buffer.byteLength(String(part))}\r\n${part}\r\n`).join('')}`));
  socket.on('data', (chunk) => {
    data += chunk;
    socket.end();
    resolve(data);
  });
  socket.on('timeout', () => { socket.destroy(); reject(new Error('Redis command timed out')); });
  socket.on('error', reject);
});

const fromRedis = async (key) => {
  const result = await redisCommand(['GET', key]);
  if (result.startsWith('$-1')) return null;
  const [, value] = result.split('\r\n');
  return value ? JSON.parse(value) : null;
};

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
  const cached = await fromRedis(cacheKey);
  if (cached) return reply(200, { ...cached, source: 'cache' });

  const item = await db.send(new GetItemCommand({ TableName: process.env.TABLE_NAME, Key: { id: { S: id } } }));
  if (!item.Item) return reply(404, { error: 'Note not found.' });
  const note = { id: item.Item.id.S, note: item.Item.note.S };
  await redisCommand(['SET', cacheKey, JSON.stringify(note), 'EX', '60']);
  return reply(200, { ...note, source: 'database' });
};
