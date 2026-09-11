export const handler = async (event) => {
  for (const record of event.Records) {
    const job = JSON.parse(record.body);
    // A deliberate, deterministic failure lets the queue redrive policy be tested end-to-end.
    if (job.fail) throw new Error(`Deliberate failure for job ${job.id}`);
    const { DynamoDBClient, PutItemCommand } = await import('@aws-sdk/client-dynamodb');
    await new DynamoDBClient({}).send(new PutItemCommand({ TableName: process.env.TABLE_NAME, Item: { id: { S: job.id }, payload: { S: job.payload }, status: { S: 'completed' } } }));
  }
};
