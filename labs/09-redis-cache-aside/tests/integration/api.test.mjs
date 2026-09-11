import assert from 'node:assert/strict';
const apiUrl = process.env.API_URL;
const expect = async (response, status) => {
  const body = await response.text();
  assert.equal(response.status, status, body);
  return JSON.parse(body);
};
const create = await fetch(apiUrl, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ note: 'cache me' }) });
const note = await expect(create, 201);
const first = await fetch(`${apiUrl}/${note.id}`);
assert.equal((await expect(first, 200)).source, 'database');
const second = await fetch(`${apiUrl}/${note.id}`);
assert.equal((await expect(second, 200)).source, 'cache');
await expect(await fetch(`${apiUrl}/missing`), 404);
console.log('Lab 09 integration tests passed.');
