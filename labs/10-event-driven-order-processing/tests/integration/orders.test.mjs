import assert from 'node:assert/strict';

const apiUrl = process.env.API_URL;
const ordersTable = process.env.ORDERS_TABLE_NAME;
const auditTable = process.env.AUDIT_TABLE_NAME;
assert.ok(apiUrl && ordersTable && auditTable, 'API_URL, ORDERS_TABLE_NAME, and AUDIT_TABLE_NAME are required');

const expectStatus = async (response, expected) => {
  const body = await response.text();
  assert.equal(response.status, expected, `expected ${expected}, got ${response.status}: ${body}`);
  return body;
};
const scan = async (TableName) => {
  const response = await fetch('http://localhost:4566/', {
    method: 'POST', headers: { 'content-type': 'application/x-amz-json-1.0', 'x-amz-target': 'DynamoDB_20120810.Scan' }, body: JSON.stringify({ TableName }),
  });
  return JSON.parse(await expectStatus(response, 200));
};

const accepted = await fetch(apiUrl, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ customerId: 'customer-42', quantity: 2 }) });
const order = JSON.parse(await expectStatus(accepted, 202));
assert.match(order.id, /^[0-9a-f-]{36}$/);

const deadline = Date.now() + 25_000;
let completed = false;
let audited = false;
while (Date.now() < deadline && !(completed && audited)) {
  const [orders, audits] = await Promise.all([scan(ordersTable), scan(auditTable)]);
  completed = orders.Items.some((item) => item.id.S === order.id && item.status.S === 'completed' && item.quantity.N === '2');
  audited = audits.Items.some((item) => item.orderId.S === order.id && item.status.S === 'completed' && item.eventType.S === 'order.completed');
  if (!(completed && audited)) await new Promise((resolve) => setTimeout(resolve, 300));
}
assert.ok(completed, 'worker did not persist the order within 25 seconds');
assert.ok(audited, 'audit consumer did not persist the order.completed event within 25 seconds');

await expectStatus(await fetch(apiUrl, { method: 'POST', headers: { 'content-type': 'application/json' }, body: '{}' }), 400);
await expectStatus(await fetch(`${apiUrl}/unknown`), 404);
console.log('Lab 10 end-to-end integration test passed.');
