export const handler = async (event) => {
  const { DynamoDBClient, PutItemCommand } = await import('@aws-sdk/client-dynamodb');
  const client = new DynamoDBClient({});
  const order = event.detail;
  if (!order?.id || order.status !== 'completed') throw new Error('Expected a completed order event.');
  await client.send(new PutItemCommand({
    TableName: process.env.AUDIT_TABLE_NAME,
    Item: { orderId: { S: order.id }, customerId: { S: order.customerId }, eventType: { S: event['detail-type'] }, status: { S: order.status } },
  }));
};
