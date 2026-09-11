import { randomUUID } from 'node:crypto';
const response = (statusCode, body) => ({ statusCode, headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) });
export const handler = async (event) => {
  let payload;
  try { payload = typeof event.body === 'string' ? JSON.parse(event.body) : event.body; } catch { return response(400, { error: 'Request body must be valid JSON.' }); }
  if (!payload || typeof payload.payload !== 'string' || payload.payload.trim().length === 0) return response(400, { error: 'The "payload" field is required.' });
  const notification = { id: randomUUID(), payload: payload.payload.trim() };
  const { SNSClient, PublishCommand } = await import('@aws-sdk/client-sns');
  await new SNSClient({}).send(new PublishCommand({ TopicArn: process.env.TOPIC_ARN, Message: JSON.stringify(notification) }));
  return response(202, notification);
};
