import assert from 'node:assert/strict';
const { API_URL: apiUrl, EMAIL_TABLE_NAME: emailTable, AUDIT_TABLE_NAME: auditTable } = process.env;
assert.ok(apiUrl && emailTable && auditTable, 'API_URL, EMAIL_TABLE_NAME, and AUDIT_TABLE_NAME are required');
const expectStatus = async (response, expected) => { const body = await response.text(); assert.equal(response.status, expected, body); return body; };
const scan = async (TableName) => JSON.parse(await expectStatus(await fetch('http://localhost:4566/', { method: 'POST', headers: { 'content-type': 'application/x-amz-json-1.0', 'x-amz-target': 'DynamoDB_20120810.Scan' }, body: JSON.stringify({ TableName }) }), 200));
const accepted = await fetch(apiUrl, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ payload: 'fan this out' }) });
const notification = JSON.parse(await expectStatus(accepted, 202));
const deadline = Date.now() + 25_000;
let received = false;
while (Date.now() < deadline && !received) {
  const [email, audit] = await Promise.all([scan(emailTable), scan(auditTable)]);
  received = email.Items.some((item) => item.id.S === notification.id && item.payload.S === notification.payload && item.consumer.S === 'email') && audit.Items.some((item) => item.id.S === notification.id && item.payload.S === notification.payload && item.consumer.S === 'audit');
  if (!received) await new Promise((resolve) => setTimeout(resolve, 300));
}
assert.ok(received, 'both independent fan-out consumers should persist the notification');
await expectStatus(await fetch(apiUrl, { method: 'POST', headers: { 'content-type': 'application/json' }, body: '{' }), 400);
await expectStatus(await fetch(apiUrl, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({}) }), 400);
await expectStatus(await fetch(`${apiUrl}/unknown`), 404);
console.log('Lab 04 integration tests passed.');
