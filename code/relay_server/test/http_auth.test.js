'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { startServer, post, signUp, open, capture } = require('./helpers');

test('sign up, sign in, and what the answers look like', async (t) => {
  const s = await startServer();
  t.after(() => s.stop());

  const reg = await post(s.base, '/api/register', { username: 'Alice_1', password: 'a long enough password' });
  assert.equal(reg.status, 200);
  assert.equal(reg.body.user.username, 'alice_1'); // normalized
  assert.match(reg.body.token, /^[A-Za-z0-9_-]{43}$/); // 32 random bytes, base64url
  assert.equal(reg.headers.get('cache-control'), 'no-store');
  assert.equal(reg.headers.get('x-content-type-options'), 'nosniff');

  const login = await post(s.base, '/api/login', { username: 'ALICE_1', password: 'a long enough password' });
  assert.equal(login.status, 200);
  assert.notEqual(login.body.token, reg.body.token); // each sign-in gets its own token

  // The server never stores the password or the token themselves.
  const stored = JSON.stringify([...s.store.users.values()]) + JSON.stringify([...s.store.sessions.entries()]);
  assert.ok(!stored.includes('a long enough password'));
  assert.ok(!stored.includes(reg.body.token));
  assert.ok(stored.includes('argon2id$'));

  capture(
    'relay_http_auth.txt',
    `POST /api/register   -> ${reg.status}  username normalized to "${reg.body.user.username}", token of ${reg.body.token.length} characters\n` +
      `POST /api/login      -> ${login.status}  a second, different token\n` +
      `response headers: Cache-Control: ${reg.headers.get('cache-control')}, X-Content-Type-Options: ${reg.headers.get('x-content-type-options')}`,
  );
});

test('every way a sign-up or sign-in can be refused', async (t) => {
  const s = await startServer({ registerBurst: 100 }); // do not trip the limit here
  t.after(() => s.stop());
  await signUp(s.base, 'alice', 'a long enough password');

  const rows = [];
  const check = async (label, route, body, expectedStatus, extraHeaders) => {
    const res = await post(s.base, route, body, extraHeaders);
    rows.push(`${label.padEnd(44)} ${res.status}  ${res.body.code ?? 'ok'}: ${res.body.message ?? ''}`);
    assert.equal(res.status, expectedStatus, label);
    return res;
  };

  await check('sign up: username taken (any case)', '/api/register', { username: 'ALICE', password: 'another long password' }, 409);
  await check('sign up: password too short', '/api/register', { username: 'bob', password: 'short' }, 400);
  await check('sign up: bad username', '/api/register', { username: 'b o b', password: 'a long enough password' }, 400);
  await check('sign up: password is a number', '/api/register', { username: 'bob', password: 1234567890123 }, 400);
  await check('sign up: fields missing', '/api/register', {}, 400);
  const wrong = await check('sign in: wrong password', '/api/login', { username: 'alice', password: 'not the password' }, 401);
  const unknown = await check('sign in: no such user', '/api/login', { username: 'nobody', password: 'not the password' }, 401);
  assert.equal(wrong.body.message, unknown.body.message, 'the two failures must be indistinguishable');
  await check('sign in: password not text', '/api/login', { username: 'alice', password: { $ne: null } }, 401);
  await check('body is not JSON', '/api/login', '{not json', 400);
  await check('body is a JSON array', '/api/login', '[]', 400);
  await check('body is a JSON string', '/api/login', '"text"', 400);
  await check('body too large (5000 bytes, limit 4096)', '/api/login', { username: 'alice', password: 'x'.repeat(5000) }, 413);
  await check('wrong content type', '/api/login', 'username=alice', 400, { 'content-type': 'text/plain' });

  const notFound = await fetch(`${s.base}/api/unknown`);
  assert.equal(notFound.status, 404);
  const wrongMethod = await fetch(`${s.base}/api/login`);
  assert.equal(wrongMethod.status, 404);

  capture('relay_http_failures.txt', rows.join('\n'));
});

test('two simultaneous sign-ups for one name: exactly one wins', async (t) => {
  const s = await startServer();
  t.after(() => s.stop());
  const attempts = await Promise.all(
    Array.from({ length: 5 }, () => post(s.base, '/api/register', { username: 'racer', password: 'a long enough password' })),
  );
  const statuses = attempts.map((a) => a.status).sort();
  assert.deepEqual(statuses, [200, 409, 409, 409, 409]);
  assert.equal([...s.store.users.values()].filter((u) => u.username === 'racer').length, 1);
});

test('sign-ups are limited too: a sixth in a row from one address is refused', async (t) => {
  const s = await startServer();
  t.after(() => s.stop());
  const statuses = [];
  for (let i = 0; i < 6; i++) {
    statuses.push((await post(s.base, '/api/register', { username: `user_${i}`, password: 'a long enough password' })).status);
  }
  assert.deepEqual(statuses, [200, 200, 200, 200, 200, 429]);
});

test('repeated sign-in attempts are rate limited, per user and address', async (t) => {
  let now = 1_000_000;
  const s = await startServer({ now: () => now });
  t.after(() => s.stop());
  await signUp(s.base, 'alice', 'a long enough password');

  const statuses = [];
  for (let i = 0; i < 12; i++) {
    const r = await post(s.base, '/api/login', { username: 'alice', password: 'guess number ' + i });
    statuses.push(r.status);
  }
  // The register call above used a different limiter; login allows 10 at once.
  assert.deepEqual(statuses.slice(0, 10), Array(10).fill(401));
  assert.deepEqual(statuses.slice(10), [429, 429]);

  const refused = await post(s.base, '/api/login', { username: 'alice', password: 'a long enough password' });
  assert.equal(refused.status, 429); // even the right password is refused while limited
  assert.ok(Number(refused.headers.get('retry-after')) >= 1);

  // A different username from the same address has its own allowance.
  const other = await post(s.base, '/api/login', { username: 'someone_else', password: 'x' });
  assert.equal(other.status, 401);

  now += 60_000; // a minute later, the allowance has refilled
  const later = await post(s.base, '/api/login', { username: 'alice', password: 'a long enough password' });
  assert.equal(later.status, 200);

  capture(
    'relay_login_limit.txt',
    `12 wrong guesses in a row for one user: ${statuses.join(' ')}\n` +
      `then the correct password, while limited:   ${refused.status} (Retry-After: ${refused.headers.get('retry-after')} s)\n` +
      `another username, same address:            ${other.status} (its own allowance)\n` +
      `a minute later, correct password:          ${later.status}`,
  );
});

test('tokens: logout and expiry end a session; sockets need a valid token', async (t) => {
  let now = 5_000_000;
  const s = await startServer({ now: () => now });
  t.after(() => s.stop());
  const { token } = await signUp(s.base, 'alice', 'a long enough password');

  const results = [];
  const attempt = async (label, auth) => {
    try {
      const socket = await open(s.base, auth);
      socket.close();
      results.push(`${label.padEnd(34)} connected`);
      return true;
    } catch (error) {
      results.push(`${label.padEnd(34)} refused: ${error.message}`);
      return false;
    }
  };

  assert.equal(await attempt('valid token', token), true);
  assert.equal(await attempt('no token', undefined), false);
  assert.equal(await attempt('made-up token', 'x'.repeat(43)), false);
  assert.equal(await attempt('token of a huge size', 'x'.repeat(5000)), false);
  assert.equal(await attempt('token that is not text', { a: 1 }), false);

  const out = await post(s.base, '/api/logout', {}, { authorization: `Bearer ${token}` });
  assert.equal(out.status, 200);
  assert.equal(await attempt('same token after logout', token), false);

  const fresh = (await post(s.base, '/api/login', { username: 'alice', password: 'a long enough password' })).body.token;
  assert.equal(await attempt('fresh token', fresh), true);
  now += 8 * 24 * 60 * 60 * 1000; // eight days later
  assert.equal(await attempt('fresh token after 8 days (limit is 7)', fresh), false);

  capture('relay_tokens.txt', results.join('\n'));
});
