import assert from 'node:assert/strict';

const cluster = process.env.CLUSTER_NAME;
assert.ok(cluster, 'CLUSTER_NAME is required');

const post = async (target, body) => {
  const response = await fetch('http://localhost:4566/', {
    method: 'POST', headers: { 'content-type': 'application/x-amz-json-1.1', 'x-amz-target': target }, body: JSON.stringify(body),
  });
  const text = await response.text();
  assert.equal(response.status, 200, `${target}: ${response.status} ${text}`);
  return JSON.parse(text);
};

const before = await post('AmazonEC2ContainerServiceV20141113.ListTasks', { cluster, desiredStatus: 'STOPPED' });
const existingTaskArns = new Set(before.taskArns ?? []);
const event = await post('AWSEvents.PutEvents', { Entries: [{
  Source: 'lab.architecture', DetailType: 'run-task', EventBusName: 'default', Detail: JSON.stringify({ runId: crypto.randomUUID() }),
}] });
assert.equal(event.FailedEntryCount, 0);

const deadline = Date.now() + 30_000;
let taskArn;
while (Date.now() < deadline && !taskArn) {
  const listed = await post('AmazonEC2ContainerServiceV20141113.ListTasks', { cluster, desiredStatus: 'STOPPED' });
  taskArn = listed.taskArns?.find((arn) => !existingTaskArns.has(arn));
  if (!taskArn) await new Promise((resolve) => setTimeout(resolve, 500));
}
assert.ok(taskArn, 'EventBridge did not create a stopped ECS task within 30 seconds');

const described = await post('AmazonEC2ContainerServiceV20141113.DescribeTasks', { cluster, tasks: [taskArn] });
assert.equal(described.tasks?.[0]?.lastStatus, 'STOPPED');
assert.equal(described.tasks[0].group, 'family:lab06-scheduled-task-worker');
assert.equal(described.tasks[0].containers?.[0]?.exitCode, 0, JSON.stringify(described.tasks[0]));
console.log('Lab 06 EventBridge → ECS integration test passed.');
