import assert from 'node:assert/strict';
import net from 'node:net';
import { test } from 'node:test';
import { parseReply, redisCommand, readThroughCache } from '../../src/redis.mjs';

test('RESP bulk frames remain incomplete across every byte boundary, including UTF-8 and CRLF', () => {
  const value = 'hello 🌍\r\n' + 'x'.repeat(100_000);
  const frame = Buffer.from(`$${Buffer.byteLength(value)}\r\n${value}\r\n`);
  for (const boundary of [1, 4, 8, 15, 16, frame.length - 2, frame.length - 1]) {
    assert.equal(parseReply(frame.subarray(0, boundary)), undefined);
  }
  assert.equal(parseReply(frame), value);
  assert.equal(parseReply(Buffer.from('$-1\r\n')), null);
  assert.equal(parseReply(Buffer.from('$0\r\n\r\n')), '');
  assert.equal(parseReply(Buffer.from('+OK\r\n')), 'OK');
  assert.throws(() => parseReply(Buffer.from('-ERR rejected\r\n')), /Redis error/);
  assert.throws(() => parseReply(Buffer.from('$1048577\r\n')), /size limit/);
  assert.throws(() => parseReply(Buffer.from('$2\r\nhiXX')), /terminator/);
});

async function withServer(serve, check) {
  const sockets = new Set();
  const server = net.createServer((socket) => {
    sockets.add(socket);
    socket.on('error', () => {});
    socket.on('close', () => sockets.delete(socket));
    socket.once('data', () => serve(socket));
  });
  await new Promise((resolve, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolve); });
  try { await check(`127.0.0.1:${server.address().port}`); }
  finally {
    for (const socket of sockets) socket.destroy();
    await new Promise((resolve) => server.close(resolve));
  }
}

test('socket waits for a fragmented reply', () => withServer((socket) => {
  socket.write('$5\r\nhe');
  setTimeout(() => socket.end('llo\r\n'), 10);
}, async (endpoint) => assert.equal(await redisCommand(['GET', 'key'], { endpoint }), 'hello')));

test('socket rejects early EOF', () => withServer((socket) => socket.end('$5\r\nhe'), async (endpoint) => {
  await assert.rejects(redisCommand(['GET', 'key'], { endpoint }), /complete reply/);
}));

test('socket enforces total command deadline', () => withServer(() => {}, async (endpoint) => {
  await assert.rejects(redisCommand(['GET', 'key'], { endpoint, timeoutMs: 25 }), /timed out/);
}));

test('cache read and write outages preserve database result', async () => {
  let reads = 0;
  const result = await readThroughCache('note:1', async () => { reads++; return { id: '1', note: 'saved' }; }, async () => { throw new Error('offline'); });
  assert.deepEqual(result, { id: '1', note: 'saved', source: 'database' });
  assert.equal(reads, 1);
});

test('cache hit bypasses DB; corrupt entries refill; absent DB items remain absent', async () => {
  const note = { id: '1', note: 'saved' };
  assert.deepEqual(await readThroughCache('note:1', () => assert.fail('unexpected DB read'), async () => JSON.stringify(note)), { ...note, source: 'cache' });
  const commands = [];
  assert.deepEqual(await readThroughCache('note:1', async () => note, async (command) => { commands.push(command); return 'broken json'; }), { ...note, source: 'database' });
  assert.equal(commands[1][0], 'SET');
  assert.equal(await readThroughCache('missing', async () => null, async () => null), null);
  await assert.rejects(readThroughCache('note:1', async () => { throw new Error('DB unavailable'); }, async () => null), /DB unavailable/);
});
