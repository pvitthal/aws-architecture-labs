export const handler = async (event) => {
  const { DynamoDBClient, PutItemCommand } = await import('@aws-sdk/client-dynamodb');
  const { EventBridgeClient, PutEventsCommand } = await import('@aws-sdk/client-eventbridge');
  const dynamodb = new DynamoDBClient({});
  const eventbridge = new EventBridgeClient({});

  await Promise.all(event.Records.map(async (record) => {
    const order = JSON.parse(record.body);
    const completed = { ...order, status: 'completed' };
    await dynamodb.send(new PutItemCommand({
      TableName: process.env.ORDERS_TABLE_NAME,
      Item: {
        id: { S: completed.id }, customerId: { S: completed.customerId },
        quantity: { N: String(completed.quantity) }, status: { S: completed.status },
      },
    }));
    const result = await eventbridge.send(new PutEventsCommand({ Entries: [{
      Source: 'lab.orders', DetailType: 'order.completed', EventBusName: 'default', Detail: JSON.stringify(completed),
    }] }));
    if (result.FailedEntryCount) throw new Error(`EventBridge rejected completed order ${completed.id}`);
  }));
};
