import assert from 'node:assert/strict';
const apiUrl = process.env.API_URL;
const tableName = process.env.TABLE_NAME;
assert.ok(apiUrl && tableName, 'API_URL and TABLE_NAME are required');
const body = JSON.stringify({ payload: 'render monthly statement' });
const accepted = await fetch(apiUrl, { method: 'POST', headers: { 'content-type': 'application/json' }, body });
assert.equal(accepted.status, 202, await accepted.text());
const job = await accepted.json();
const deadline = Date.now() + 20_000;
let submitted;
while (Date.now() < deadline && !submitted) {
  const scan = await fetch('http://localhost:4566/', { method: 'POST', headers: { 'content-type': 'application/x-amz-json-1.0', 'x-amz-target': 'DynamoDB_20120810.Scan' }, body: JSON.stringify({ TableName: tableName }) });
  assert.equal(scan.status, 200, await scan.text());
  submitted = (await scan.json()).Items.find((item) => item.id.S === job.id);
  if (!submitted) await new Promise((resolve) => setTimeout(resolve, 300));
}
assert.ok(submitted, 'dispatcher did not record a workflow submission within 20 seconds');
assert.equal(submitted.status.S, 'submitted');
assert.match(submitted.executionArn.S, /^arn:/);
for (const invalid of ['{', JSON.stringify({})]) {
  const response = await fetch(apiUrl, { method: 'POST', headers: { 'content-type': 'application/json' }, body: invalid });
  assert.equal(response.status, 400, await response.text());
}
assert.equal((await fetch(`${apiUrl}/unknown`)).status, 404);
console.log('Lab 08 integration tests passed.');
