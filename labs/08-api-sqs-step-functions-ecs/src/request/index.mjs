import { randomUUID } from 'node:crypto';

const response = (statusCode, body) => ({ statusCode, headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) });

export const handler = async (event) => {
  let body;
  try { body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body; } catch { return response(400, { error: 'Request body must be valid JSON.' }); }
  if (!body || typeof body.payload !== 'string' || body.payload.trim().length === 0) return response(400, { error: 'The "payload" field is required.' });
  const job = { id: randomUUID(), payload: body.payload.trim() };
  const { SQSClient, SendMessageCommand } = await import('@aws-sdk/client-sqs');
  const QueueUrl = process.env.QUEUE_URL.replace('://localhost:', '://localhost.floci.io:');
  await new SQSClient({}).send(new SendMessageCommand({ QueueUrl, MessageBody: JSON.stringify(job) }));
  return response(202, job);
};
