import { randomUUID } from 'node:crypto';

const response = (statusCode, body) => ({
  statusCode,
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify(body),
});

export const handler = async (event) => {
  let input;
  try {
    input = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
  } catch {
    return response(400, { error: 'Request body must be valid JSON.' });
  }
  if (!input || typeof input.customerId !== 'string' || input.customerId.trim().length === 0 || !Number.isInteger(input.quantity) || input.quantity < 1) {
    return response(400, { error: 'A non-empty "customerId" and positive integer "quantity" are required.' });
  }

  const order = { id: randomUUID(), customerId: input.customerId.trim(), quantity: input.quantity };
  const { SQSClient, SendMessageCommand } = await import('@aws-sdk/client-sqs');
  const queueUrl = process.env.QUEUE_URL.replace('://localhost:', '://localhost.floci.io:');
  await new SQSClient({}).send(new SendMessageCommand({ QueueUrl: queueUrl, MessageBody: JSON.stringify(order) }));
  return response(202, order);
};
