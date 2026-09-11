export const handler = async (event) => {
  if (!event || typeof event.payload !== 'string' || event.payload.trim().length === 0) {
    throw new Error('payload is required');
  }

  // `forceFailure` makes the failure path deterministic and keeps the retry/catch
  // contract observable without relying on an external fault.
  if (event.forceFailure === true) throw new Error('requested processing failure');

  return { id: event.id, payload: event.payload.trim(), status: 'processed' };
};
