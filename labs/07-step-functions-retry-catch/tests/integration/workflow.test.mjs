import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';

const stateMachineArn = process.env.STATE_MACHINE_ARN;
assert.ok(stateMachineArn, 'STATE_MACHINE_ARN is required');
const endpoint = 'http://localhost:4566/';
const call = async (target, body) => {
  const response = await fetch(endpoint, { method: 'POST', headers: { 'content-type': 'application/x-amz-json-1.0', 'x-amz-target': target }, body: JSON.stringify(body) });
  assert.equal(response.status, 200, await response.text());
  return response.json();
};
const execute = async (input) => {
  const started = await call('AWSStepFunctions.StartExecution', { stateMachineArn, input: JSON.stringify(input), name: `test-${randomUUID()}` });
  const deadline = Date.now() + 20_000;
  while (Date.now() < deadline) {
    const result = await call('AWSStepFunctions.DescribeExecution', { executionArn: started.executionArn });
    if (result.status !== 'RUNNING') return result;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error('workflow did not finish within 20 seconds');
};
const completed = await execute({ id: 'success-1', payload: 'hello' });
assert.equal(completed.status, 'SUCCEEDED');
assert.deepEqual(JSON.parse(completed.output), { id: 'success-1', payload: 'hello', status: 'processed' });
const compensated = await execute({ id: 'failure-1', payload: 'hello', forceFailure: true });
assert.equal(compensated.status, 'SUCCEEDED');
assert.equal(JSON.parse(compensated.output).status, 'compensated');
console.log('Lab 07 integration tests passed.');
