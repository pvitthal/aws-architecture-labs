import { randomUUID } from 'node:crypto';

const response = (statusCode, body) => ({
  statusCode,
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify(body),
});

export const handler = async (event) => {
  let payload;
  try {
    payload = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
  } catch {
    return response(400, { error: 'Request body must be valid JSON.' });
  }

  if (!payload || typeof payload.payload !== 'string' || payload.payload.trim().length === 0) {
    return response(400, { error: 'The "payload" field is required.' });
  }

  const job = { id: randomUUID(), payload: payload.payload.trim() };
  const { SQSClient, SendMessageCommand } = await import('@aws-sdk/client-sqs');
  const queueUrl = process.env.QUEUE_URL.replace('://localhost:', '://localhost.floci.io:');
  await new SQSClient({}).send(new SendMessageCommand({
    QueueUrl: queueUrl,
    MessageBody: JSON.stringify(job),
  }));
  return response(202, job);
};
