import assert from 'node:assert/strict';
const apiUrl = process.env.API_URL;
const tableName = process.env.TABLE_NAME;
assert.ok(apiUrl && tableName, 'API_URL and TABLE_NAME are required');
const expectJson = async (response, status) => {
  const text = await response.text();
  assert.equal(response.status, status, text);
  return JSON.parse(text);
};
const call = async (target, body) => expectJson(await fetch('http://localhost:4566/', {
  method: 'POST', headers: { 'content-type': target.startsWith('AmazonEC2ContainerService') ? 'application/x-amz-json-1.1' : 'application/x-amz-json-1.0', 'x-amz-target': target }, body: JSON.stringify(body),
}), 200);
const body = JSON.stringify({ payload: 'render monthly statement' });
const accepted = await fetch(apiUrl, { method: 'POST', headers: { 'content-type': 'application/json' }, body });
const job = await expectJson(accepted, 202);
const deadline = Date.now() + 20_000;
let submitted;
while (Date.now() < deadline && !submitted) {
  const scan = await call('DynamoDB_20120810.Scan', { TableName: tableName });
  submitted = scan.Items.find((item) => item.id.S === job.id);
  if (!submitted) await new Promise((resolve) => setTimeout(resolve, 300));
}
assert.ok(submitted, 'dispatcher did not record a workflow submission within 20 seconds');
assert.equal(submitted.status.S, 'submitted');
assert.match(submitted.executionArn.S, /^arn:/);
const executionDeadline = Date.now() + 120_000;
let execution;
while (Date.now() < executionDeadline) {
  execution = await call('AWSStepFunctions.DescribeExecution', { executionArn: submitted.executionArn.S });
  if (execution.status !== 'RUNNING') break;
  await new Promise((resolve) => setTimeout(resolve, 500));
}
assert.equal(execution?.status, 'SUCCEEDED', JSON.stringify(execution));
assert.equal(JSON.parse(execution.input).id, job.id, 'execution must process this submitted job');
const output = JSON.parse(execution.output);
// Optimized ECS integrations return the completed task with PascalCase fields.
const task = output.Tasks?.[0] ?? output.tasks?.[0] ?? output;
const taskArn = task.TaskArn ?? task.taskArn;
const cluster = task.ClusterArn ?? task.clusterArn;
assert.ok(taskArn && cluster, `workflow output must identify its ECS task: ${execution.output}`);
const described = await call('AmazonEC2ContainerServiceV20141113.DescribeTasks', { cluster, tasks: [taskArn] });
assert.equal((described.failures ?? []).length, 0, JSON.stringify(described.failures));
assert.equal(described.tasks?.length, 1, 'ECS must return the exact workflow task');
const completedTask = described.tasks[0];
assert.equal(completedTask.taskArn, taskArn);
assert.equal(completedTask.lastStatus, 'STOPPED');
const processor = completedTask.containers.find((container) => container.name === 'processor');
assert.ok(processor, 'completed task must contain the processor');
assert.equal(processor.exitCode, 0, JSON.stringify(processor));
for (const invalid of ['{', JSON.stringify({})]) {
  const response = await fetch(apiUrl, { method: 'POST', headers: { 'content-type': 'application/json' }, body: invalid });
  assert.equal(response.status, 400, await response.text());
}
assert.equal((await fetch(`${apiUrl}/unknown`)).status, 404);
console.log('Lab 08 integration tests passed.');
