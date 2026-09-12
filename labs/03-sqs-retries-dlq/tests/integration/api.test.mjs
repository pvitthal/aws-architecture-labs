import assert from 'node:assert/strict';

const { API_URL: apiUrl, TABLE_NAME: tableName, DLQ_URL: dlqUrl } = process.env;
assert.ok(apiUrl && tableName && dlqUrl, 'API_URL, TABLE_NAME, and DLQ_URL are required');
const expectStatus = async (response, expected) => { const body = await response.text(); assert.equal(response.status, expected, body); return body; };
const request = (body) => fetch(apiUrl, { method: 'POST', headers: { 'content-type': 'application/json' }, body });
const scan = async () => JSON.parse(await expectStatus(await fetch('http://localhost:4566/', { method: 'POST', headers: { 'content-type': 'application/x-amz-json-1.0', 'x-amz-target': 'DynamoDB_20120810.Scan' }, body: JSON.stringify({ TableName: tableName }) }), 200));
const dlqMessages = async () => {
  const response = await fetch('http://localhost:4566/', { method: 'POST', headers: { 'content-type': 'application/x-amz-json-1.0', 'x-amz-target': 'AmazonSQS.ReceiveMessage' }, body: JSON.stringify({ QueueUrl: dlqUrl, MaxNumberOfMessages: 10, VisibilityTimeout: 1, WaitTimeSeconds: 0 }) });
  return JSON.parse(await expectStatus(response, 200)).Messages ?? [];
};

const succeeded = JSON.parse(await expectStatus(await request(JSON.stringify({ payload: 'survives processing' })), 202));
const failed = JSON.parse(await expectStatus(await request(JSON.stringify({ payload: 'moves to DLQ', fail: true })), 202));
// Two receives separated by the 60-second visibility timeout precede redrive.
const deadline = Date.now() + 180_000;
let complete = false;
let failedInDlq = false;
while (Date.now() < deadline && !complete) {
  const items = (await scan()).Items;
  failedInDlq ||= (await dlqMessages()).some((message) => {
    const job = JSON.parse(message.Body);
    return job.id === failed.id && job.payload === failed.payload && job.fail === true;
  });
  complete = items.some((item) => item.id.S === succeeded.id && item.status.S === 'completed') && failedInDlq;
  if (!complete) await new Promise((resolve) => setTimeout(resolve, 500));
}
assert.ok(complete, `expected successful job ${succeeded.id} and failed job ${failed.id} to reach the DLQ`);
await expectStatus(await request('{'), 400);
await expectStatus(await request(JSON.stringify({ payload: 'x', fail: 'yes' })), 400);
await expectStatus(await fetch(`${apiUrl}/unknown`), 404);
console.log('Lab 03 integration tests passed.');
