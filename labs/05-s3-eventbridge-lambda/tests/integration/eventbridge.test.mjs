import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';

const tableName = process.env.TABLE_NAME;
const bucketName = process.env.BUCKET_NAME;
assert.ok(tableName, 'TABLE_NAME is required');
assert.ok(bucketName, 'BUCKET_NAME is required');

const post = async (target, body) => {
  const response = await fetch('http://localhost:4566/', {
    method: 'POST', headers: { 'content-type': 'application/x-amz-json-1.0', 'x-amz-target': target }, body: JSON.stringify(body),
  });
  const text = await response.text();
  assert.equal(response.status, 200, `${target}: ${response.status} ${text}`);
  return JSON.parse(text);
};

const key = `integration/${crypto.randomUUID()}.json`;
const objectUrl = `http://localhost:4566/${encodeURIComponent(bucketName)}/${key.split('/').map(encodeURIComponent).join('/')}`;
const s3 = (method, body) => execFileSync('curl', [
  '--silent', '--show-error', '--fail-with-body', '--max-time', '15',
  '--aws-sigv4', 'aws:amz:us-east-1:s3', '--user', 'test:test',
  '--request', method, ...(body === undefined ? [] : ['--data-binary', body]), objectUrl,
], { encoding: 'utf8' });
s3('PUT', JSON.stringify({ integration: true }));

try {
  const deadline = Date.now() + 20_000;
  let found = false;
  while (Date.now() < deadline && !found) {
    const scan = await post('DynamoDB_20120810.Scan', { TableName: tableName });
    found = scan.Items.some((item) => item.bucket.S === bucketName && item.key.S === key && item.source.S === 'aws.s3');
    if (!found) await new Promise((resolve) => setTimeout(resolve, 300));
  }
  assert.ok(found, 'S3 PutObject did not propagate through EventBridge and Lambda within 20 seconds');
  console.log('Lab 05 S3 → EventBridge → Lambda integration test passed.');
} finally {
  s3('DELETE');
}
