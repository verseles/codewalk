import { performance } from 'node:perf_hooks';
export const now = () => performance.now();
export function remaining(end, cap = 15000) {
  const left = Math.floor(end - now());
  if (left < 1) throw new Error('shared operation deadline');
  return Math.min(cap, left);
}
