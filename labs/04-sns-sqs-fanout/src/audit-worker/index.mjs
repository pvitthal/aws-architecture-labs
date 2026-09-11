export const handler = async (event) => {
  const { DynamoDBClient, PutItemCommand } = await import('@aws-sdk/client-dynamodb');
  const client = new DynamoDBClient({});
  await Promise.all(event.Records.map(async (record) => {
    const notification = JSON.parse(record.body);
    await client.send(new PutItemCommand({ TableName: process.env.TABLE_NAME, Item: { id: { S: notification.id }, payload: { S: notification.payload }, consumer: { S: 'audit' } } }));
  }));
};
