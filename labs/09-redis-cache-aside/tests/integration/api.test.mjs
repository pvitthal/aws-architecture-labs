import assert from 'node:assert/strict';
const apiUrl = process.env.API_URL;
assert.ok(apiUrl, 'API_URL must be configured');
const expect = async (response, status) => {
  const body = await response.text();
  assert.equal(response.status, status, body);
  return JSON.parse(body);
};
// Exceeds a typical TCP chunk and exercises UTF-8 byte lengths in Redis replies.
const content = 'cache 🌍\r\n'.repeat(8_000);
const create = await fetch(apiUrl, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ note: content }) });
const note = await expect(create, 201);
const first = await fetch(`${apiUrl}/${note.id}`);
assert.deepEqual(await expect(first, 200), { ...note, source: 'database' });
const second = await fetch(`${apiUrl}/${note.id}`);
assert.deepEqual(await expect(second, 200), { ...note, source: 'cache' });
assert.equal(note.note, content.trim());
await expect(await fetch(`${apiUrl}/missing`), 404);
await expect(await fetch(apiUrl, { method: 'POST', body: '{' }), 400);
await expect(await fetch(apiUrl, { method: 'POST', body: JSON.stringify({ note: ' ' }) }), 400);
console.log('Lab 09 integration tests passed.');
