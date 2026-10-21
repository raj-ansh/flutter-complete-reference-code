'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { DEFAULT_PARAMS, hashPassword, verifyPassword, needsRehash } = require('../src/passwords');
const { capture } = require('./helpers');

test('a hash is self-describing and uses the OWASP minimum parameters', async () => {
  const started = performance.now();
  const stored = await hashPassword('correct horse battery staple');
  const ms = Math.round(performance.now() - started);
  const [algorithm, params, salt, hash] = stored.split('$');

  assert.equal(algorithm, 'argon2id');
  assert.equal(params, 'm=19456,t=2,p=1');
  assert.equal(Buffer.from(salt, 'base64').length, 16);
  assert.equal(Buffer.from(hash, 'base64').length, 32);

  capture(
    'relay_password_hash.txt',
    `stored value: ${stored}\n` +
      `  algorithm:   ${algorithm}\n` +
      `  parameters:  ${params}   (memory in KiB, passes, parallelism)\n` +
      `  salt:        ${salt}   (${Buffer.from(salt, 'base64').length} random bytes)\n` +
      `  hash:        ${hash}   (${Buffer.from(hash, 'base64').length} bytes)\n` +
      `time to hash one password on this machine: about ${ms} ms`,
  );
});

test('the right password verifies, wrong ones do not', async () => {
  const stored = await hashPassword('correct horse battery staple');
  assert.equal(await verifyPassword('correct horse battery staple', stored), true);
  assert.equal(await verifyPassword('correct horse battery stapl', stored), false);
  assert.equal(await verifyPassword('', stored), false);
  assert.equal(await verifyPassword('CORRECT HORSE BATTERY STAPLE', stored), false);
});

test('the same password gets a different hash every time (a fresh salt)', async () => {
  const a = await hashPassword('same password');
  const b = await hashPassword('same password');
  assert.notEqual(a, b);
  assert.equal(await verifyPassword('same password', a), true);
  assert.equal(await verifyPassword('same password', b), true);
});

test('damaged or foreign stored values fail safely instead of throwing', async () => {
  for (const stored of [undefined, null, '', 'plain', 'bcrypt$10$x$y', 'argon2id$m=x,t=2,p=1$AA==$AA==', 'argon2id$m=8,t=1,p=1$$']) {
    assert.equal(await verifyPassword('anything', stored), false, String(stored));
  }
});

test('long passwords, any Unicode, and even a NUL byte are accepted as they are', async () => {
  for (const pw of ['x'.repeat(128), 'pässwörd-日本語-🔑', 'null\u0000byte password']) {
    const stored = await hashPassword(pw, { memory: 8, passes: 1, parallelism: 1 });
    assert.equal(await verifyPassword(pw, stored), true, pw.slice(0, 12));
    // Changing only the last character must change the answer: nothing is cut off.
    assert.equal(await verifyPassword(`${pw.slice(0, -1)}!`, stored), false);
  }
});

test('old hashes keep working after the parameters are raised, and are flagged for rehash', async () => {
  const weak = { memory: 8, passes: 1, parallelism: 1 };
  const stored = await hashPassword('pw for upgrade test', weak);
  assert.equal(needsRehash(stored, weak), false);
  assert.equal(needsRehash(stored, DEFAULT_PARAMS), true);
  assert.equal(await verifyPassword('pw for upgrade test', stored), true); // still verifies
  assert.equal(needsRehash('not a hash'), true);
});

test('timingSafeEqual needs equal lengths, which is why verify checks first', async () => {
  const { timingSafeEqual } = require('node:crypto');
  assert.throws(() => timingSafeEqual(Buffer.alloc(4), Buffer.alloc(5)), RangeError);
  // A stored hash of an unexpected length therefore yields false, not an exception.
  const stored = `argon2id$m=8,t=1,p=1$${Buffer.alloc(16).toString('base64')}$${Buffer.alloc(5).toString('base64')}`;
  assert.equal(await verifyPassword('x', stored), false);
});
