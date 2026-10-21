'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const v = require('../src/validation');
const { RateLimiter } = require('../src/rate_limit');
const { capture } = require('./helpers');

test('what each validator accepts and says', () => {
  const rows = [];
  const row = (field, input, result) => {
    const shown = typeof input === 'string' && input.length > 24 ? `${input.slice(0, 8)}…(${[...input].length} chars)` : JSON.stringify(input);
    rows.push(`${field.padEnd(9)}${String(shown).padEnd(24)}${result.ok ? `ok -> ${JSON.stringify(result.value).slice(0, 30)}` : result.message}`);
    return result;
  };

  assert.equal(row('username', '  Sam_01 ', v.username('  Sam_01 ')).value, 'sam_01');
  for (const bad of ['ab', 'a'.repeat(21), 'has space', 'sam!', 'émile', 7, null, undefined]) {
    assert.equal(row('username', bad, v.username(bad)).ok, false, String(bad));
  }

  assert.equal(row('password', 'x'.repeat(10), v.password('x'.repeat(10))).ok, true);
  assert.equal(row('password', 'short', v.password('short')).ok, false);
  assert.equal(row('password', 'x'.repeat(129), v.password('x'.repeat(129))).ok, false);
  assert.equal(row('password', '🔑'.repeat(10), v.password('🔑'.repeat(10))).ok, true); // 10 characters, 40 bytes
  assert.equal(row('password', 12345678901, v.password(12345678901)).ok, false);

  assert.equal(row('room', '  Garden   club ', v.roomName('  Garden   club ')).value, 'Garden club');
  // Any run of white space, a newline included, becomes a single space.
  assert.equal(row('room', 'line\nbreak', v.roomName('line\nbreak')).value, 'line break');
  for (const bad of ['', '   ', 'x'.repeat(41), 'nul\u0000', 'bell\u0007', {}]) {
    assert.equal(row('room', bad, v.roomName(bad)).ok, false);
  }

  assert.equal(row('message', ' hello\nworld ', v.messageText(' hello\nworld ')).value, 'hello\nworld');
  for (const bad of ['', '  ', 'x'.repeat(2001), 'bell\u0007', 5, ['a']]) {
    assert.equal(row('message', bad, v.messageText(bad)).ok, false);
  }

  assert.equal(v.id('0123456789abcdef').ok, true);
  for (const bad of ['', 'short', '../../etc', 'UPPERCASE12345678', 12, null]) {
    assert.equal(v.id(bad).ok, false, String(bad));
  }
  assert.equal(v.integerInRange(undefined, 1, 10, 5).value, 5);
  assert.equal(v.integerInRange(3, 1, 10, 5).value, 3);
  for (const bad of [0, 11, 2.5, '3', NaN]) assert.equal(v.integerInRange(bad, 1, 10, 5).ok, false);

  capture('relay_validation.txt', rows.join('\n'));
});

test('a token bucket allows a burst, then a steady rate, then recovers', () => {
  let now = 0;
  const limiter = new RateLimiter({ capacity: 3, refillPerSecond: 1, now: () => now });
  const log = [];
  const attempt = (label) => {
    const r = limiter.take('user');
    log.push(`t=${String(now).padStart(5)} ms  ${label.padEnd(18)} ${r.allowed ? 'allowed' : `refused, retry in ${r.retryAfterMs} ms`}`);
    return r;
  };

  assert.equal(attempt('1st').allowed, true);
  assert.equal(attempt('2nd').allowed, true);
  assert.equal(attempt('3rd').allowed, true);
  const refused = attempt('4th, same instant');
  assert.equal(refused.allowed, false);
  assert.equal(refused.retryAfterMs, 1000);
  now = 400;
  assert.equal(attempt('after 0.4 s').retryAfterMs, 600);
  now = 1000;
  assert.equal(attempt('after 1 s').allowed, true);
  assert.equal(attempt('immediately again').allowed, false);
  now = 60_000;
  assert.equal(limiter.take('user').allowed, true);
  assert.equal(limiter.take('other').allowed, true, 'keys are independent');
  capture('relay_rate_limit.txt', log.join('\n'));

  limiter.sweep(1000);
  assert.equal(limiter.buckets.size, 2); // both were just used, so both stay
  now = 10 * 60_000;
  limiter.sweep(1000);
  assert.equal(limiter.buckets.size, 0); // idle keys are forgotten
});
