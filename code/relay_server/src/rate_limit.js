'use strict';

// #docregion bucket
/**
 * A token bucket per key: each key may make [capacity] requests at once and
 * then [refillPerSecond] more per second. The clock is a parameter so tests
 * need not wait.
 */
class RateLimiter {
  constructor({ capacity, refillPerSecond, now = Date.now }) {
    this.capacity = capacity;
    this.refillPerSecond = refillPerSecond;
    this.now = now;
    this.buckets = new Map(); // key -> { tokens, at }
  }

  /** @returns {{ allowed: boolean, retryAfterMs: number }} */
  take(key, cost = 1) {
    const t = this.now();
    const bucket = this.buckets.get(key) ?? { tokens: this.capacity, at: t };
    const refilled = Math.min(
      this.capacity,
      bucket.tokens + ((t - bucket.at) / 1000) * this.refillPerSecond,
    );
    bucket.at = t;
    if (refilled >= cost) {
      bucket.tokens = refilled - cost;
      this.buckets.set(key, bucket);
      return { allowed: true, retryAfterMs: 0 };
    }
    bucket.tokens = refilled;
    this.buckets.set(key, bucket);
    const missing = cost - refilled;
    return { allowed: false, retryAfterMs: Math.ceil((missing / this.refillPerSecond) * 1000) };
  }

  /** Forget idle keys so the map cannot grow without limit. */
  sweep(maxIdleMs = 10 * 60 * 1000) {
    const cutoff = this.now() - maxIdleMs;
    for (const [key, bucket] of this.buckets) if (bucket.at < cutoff) this.buckets.delete(key);
  }
}
// #enddocregion bucket

module.exports = { RateLimiter };
