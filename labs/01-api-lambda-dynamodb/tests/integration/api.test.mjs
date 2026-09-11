import assert from 'node:assert/strict';

const apiUrl = process.env.API_URL;
const tableName = process.env.TABLE_NAME;
assert.ok(apiUrl, 'API_URL is required');
assert.ok(tableName, 'TABLE_NAME is required');

const request = (body) => fetch(apiUrl, {
  method: 'POST',
  headers: { 'content-type': 'application/json' },
  body,
});

const expectStatus = async (response, expected) => {
  const body = await response.text();
  assert.equal(response.status, expected, `expected ${expected}, got ${response.status}: ${body}`);
  return body;
};

const created = await request(JSON.stringify({ note: 'Floci integration test' }));
const createdBody = JSON.parse(await expectStatus(created, 201));
assert.match(createdBody.id, /^[0-9a-f-]{36}$/);
assert.equal(createdBody.note, 'Floci integration test');

const table = await fetch('http://localhost:4566/', {
  method: 'POST',
  headers: {
    'content-type': 'application/x-amz-json-1.0',
    'x-amz-target': 'DynamoDB_20120810.Scan',
  },
  body: JSON.stringify({ TableName: tableName }),
});
const tableBody = JSON.parse(await expectStatus(table, 200));
assert.ok(tableBody.Items.some((item) => item.id.S === createdBody.id && item.note.S === createdBody.note),
  'created API response must be persisted in DynamoDB');

const malformed = await request('{');
await expectStatus(malformed, 400);

const missingField = await request(JSON.stringify({}));
await expectStatus(missingField, 400);

const unknown = await fetch(`${apiUrl}/unknown`);
await expectStatus(unknown, 404);

console.log('Lab 01 integration tests passed.');
