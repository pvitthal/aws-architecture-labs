import net from 'node:net';

// GET/SET use RESP2 scalar replies. TCP chunks and UTF-8 characters need not align.
export function parseReply(buffer) {
  const lineEnd = buffer.indexOf('\r\n');
  if (lineEnd < 0) return undefined;
  const type = String.fromCharCode(buffer[0]);
  const header = buffer.subarray(1, lineEnd).toString('utf8');
  if (type === '-') throw new Error(`Redis error: ${header}`);
  if (type === '+') return header;
  if (type !== '$') throw new Error('Unsupported Redis reply');
  if (!/^-?\d+$/.test(header)) throw new Error('Invalid Redis bulk length');
  const length = Number(header);
  if (length === -1) return null;
  if (!Number.isSafeInteger(length) || length < 0 || length > 1_048_576) throw new Error('Redis reply exceeds size limit');
  const end = lineEnd + 2 + length;
  if (buffer.length < end + 2) return undefined;
  if (buffer[end] !== 13 || buffer[end + 1] !== 10) throw new Error('Invalid Redis bulk terminator');
  return buffer.subarray(lineEnd + 2, end).toString('utf8');
}

export const redisCommand = (command, { endpoint = process.env.REDIS_ENDPOINT, timeoutMs = 2_000 } = {}) => new Promise((resolve, reject) => {
  if (!endpoint) return reject(new Error('Redis endpoint is not configured'));
  const address = new URL(`redis://${endpoint}`);
  const socket = net.createConnection({ host: address.hostname, port: Number(address.port || 6379) });
  let buffer = Buffer.alloc(0);
  let settled = false;
  const finish = (error, value) => {
    if (settled) return;
    settled = true;
    clearTimeout(deadline);
    socket.destroy();
    if (error) reject(error); else resolve(value);
  };
  const deadline = setTimeout(() => finish(new Error('Redis command timed out')), timeoutMs);
  socket.on('connect', () => socket.write(`*${command.length}\r\n${command.map((part) => `$${Buffer.byteLength(String(part))}\r\n${part}\r\n`).join('')}`));
  socket.on('data', (chunk) => {
    buffer = Buffer.concat([buffer, chunk]);
    if (buffer.length > 1_048_640) return finish(new Error('Redis reply exceeds size limit'));
    try {
      const reply = parseReply(buffer);
      if (reply !== undefined) finish(null, reply);
    } catch (error) { finish(error); }
  });
  socket.on('error', (error) => finish(error));
  socket.on('end', () => finish(new Error('Redis closed before a complete reply')));
  socket.on('close', () => finish(new Error('Redis connection closed')));
});

export async function readThroughCache(key, load, command = redisCommand) {
  try {
    const raw = await command(['GET', key]);
    if (raw !== null) {
      const cached = JSON.parse(raw);
      if (cached && typeof cached.id === 'string' && typeof cached.note === 'string') return { ...cached, source: 'cache' };
    }
  } catch { /* Cache outages and corrupt entries are cache misses. */ }
  const note = await load();
  if (!note) return null;
  try { await command(['SET', key, JSON.stringify(note), 'EX', '60']); }
  catch { /* Cache fill failure must not discard a successful database read. */ }
  return { ...note, source: 'database' };
}
