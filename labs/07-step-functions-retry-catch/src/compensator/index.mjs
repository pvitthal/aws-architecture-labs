export const handler = async (event) => ({
  id: event.id,
  payload: event.payload,
  status: 'compensated',
  reason: event.error?.Cause ?? 'processing failed',
});
