import assert from 'node:assert/strict';

const apiUrl = process.env.API_URL;
const tableName = process.env.TABLE_NAME;
assert.ok(apiUrl, 'API_URL is required');
assert.ok(tableName, 'TABLE_NAME is required');

const expectStatus = async (response, expected) => {
  const body = await response.text();
  assert.equal(response.status, expected, `expected ${expected}, got ${response.status}: ${body}`);
  return body;
};

const request = (body) => fetch(apiUrl, {
  method: 'POST',
  headers: { 'content-type': 'application/json' },
  body,
});

const accepted = await request(JSON.stringify({ payload: 'process asynchronously' }));
const job = JSON.parse(await expectStatus(accepted, 202));
assert.match(job.id, /^[0-9a-f-]{36}$/);

const deadline = Date.now() + 20_000;
let persisted = false;
while (Date.now() < deadline && !persisted) {
  const table = await fetch('http://localhost:4566/', {
    method: 'POST',
    headers: {
      'content-type': 'application/x-amz-json-1.0',
      'x-amz-target': 'DynamoDB_20120810.Scan',
    },
    body: JSON.stringify({ TableName: tableName }),
  });
  const tableBody = JSON.parse(await expectStatus(table, 200));
  persisted = tableBody.Items.some((item) => item.id.S === job.id && item.payload.S === job.payload && item.status.S === 'completed');
  if (!persisted) await new Promise((resolve) => setTimeout(resolve, 300));
}
assert.ok(persisted, 'worker did not persist the queued job within 20 seconds');

await expectStatus(await request('{'), 400);
await expectStatus(await request(JSON.stringify({})), 400);
await expectStatus(await fetch(`${apiUrl}/unknown`), 404);

console.log('Lab 02 integration tests passed.');

