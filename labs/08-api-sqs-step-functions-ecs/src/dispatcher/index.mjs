export const handler = async (event) => {
  const { SFNClient, StartExecutionCommand } = await import('@aws-sdk/client-sfn');
  const { DynamoDBClient, PutItemCommand } = await import('@aws-sdk/client-dynamodb');
  const sfn = new SFNClient({});
  const dynamodb = new DynamoDBClient({});
  await Promise.all(event.Records.map(async ({ body }) => {
    const job = JSON.parse(body);
    const execution = await sfn.send(new StartExecutionCommand({ stateMachineArn: process.env.STATE_MACHINE_ARN, input: JSON.stringify(job), name: job.id }));
    await dynamodb.send(new PutItemCommand({ TableName: process.env.TABLE_NAME, Item: {
      id: { S: job.id }, payload: { S: job.payload }, status: { S: 'submitted' }, executionArn: { S: execution.executionArn },
    } }));
  }));
};
