export const handler = async (event) => {
  const { DynamoDBClient, PutItemCommand } = await import('@aws-sdk/client-dynamodb');
  const client = new DynamoDBClient({});

  await Promise.all(event.Records.map(async (record) => {
    const job = JSON.parse(record.body);
    await client.send(new PutItemCommand({
      TableName: process.env.TABLE_NAME,
      Item: {
        id: { S: job.id },
        payload: { S: job.payload },
        status: { S: 'completed' },
      },
    }));
  }));
};

