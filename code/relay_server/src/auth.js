'use strict';

const { randomBytes } = require('node:crypto');
const passwords = require('./passwords');
const validate = require('./validation');
const { RateLimiter } = require('./rate_limit');
const { ok, fail } = require('./results');

const DAY_MS = 24 * 60 * 60 * 1000;

class Auth {
  /**
   * @param {import('./store').Store} store
   * @param {{ now?: () => number, params?: object, tokenTtlMs?: number }} options
   */
  constructor(store, options = {}) {
    this.store = store;
    this.now = options.now ?? Date.now;
    this.params = options.params ?? passwords.DEFAULT_PARAMS;
    this.tokenTtlMs = options.tokenTtlMs ?? 7 * DAY_MS;
    // Failed and successful sign-ins both count: 10 at once, then one every 6 s.
    this.loginLimiter = new RateLimiter({
      capacity: options.loginBurst ?? 10,
      refillPerSecond: 1 / 6,
      now: this.now,
    });
    this.registerLimiter = new RateLimiter({
      capacity: options.registerBurst ?? 5,
      refillPerSecond: 1 / 60,
      now: this.now,
    });
    // A real hash of a throw-away password, used so that signing in as a user
    // that does not exist costs the same time as a wrong password.
    this._dummyHash = null; // created on first use, see login()
  }

  // #docregion register
  async register({ username, password }, clientKey = 'unknown') {
    const gate = this.registerLimiter.take(clientKey);
    if (!gate.allowed) return fail('rate_limited', 'Too many sign-ups. Try again later.', { retryAfterMs: gate.retryAfterMs });

    const name = validate.username(username);
    if (!name.ok) return fail('invalid', name.message);
    const pw = validate.password(password);
    if (!pw.ok) return fail('invalid', pw.message);
    if (this.store.findUserByName(name.value)) return fail('conflict', 'That username is taken.');

    const passwordHash = await passwords.hashPassword(pw.value, this.params);
    // Hashing took time (an await), during which another request may have
    // registered the same name. Check again, with no await between the check
    // and the insert, so that exactly one of two simultaneous sign-ups wins.
    if (this.store.findUserByName(name.value)) return fail('conflict', 'That username is taken.');
    const user = this.store.addUser({ username: name.value, passwordHash });
    return this._startSession(user);
  }
  // #enddocregion register

  // #docregion login
  async login({ username, password }, clientKey = 'unknown') {
    const gate = this.loginLimiter.take(`${clientKey}|${String(username).toLowerCase()}`);
    if (!gate.allowed) return fail('rate_limited', 'Too many attempts. Try again later.', { retryAfterMs: gate.retryAfterMs });

    this._dummyHash ??= await passwords.hashPassword('not-a-real-password', this.params);
    const name = validate.username(username);
    const user = name.ok ? this.store.findUserByName(name.value) : null;
    const matches = await passwords.verifyPassword(
      typeof password === 'string' ? password : '',
      user ? user.passwordHash : this._dummyHash, // always do the same work
    );
    // One message for "no such user" and "wrong password": telling them apart
    // would let anyone discover which usernames exist.
    if (!user || !matches) return fail('unauthorized', 'Wrong username or password.');
    return this._startSession(user);
  }
  // #enddocregion login

  logout(token) {
    if (typeof token === 'string') this.store.removeSession(token);
    return ok();
  }

  /** The user a token belongs to, or null if it is unknown or expired. */
  authenticate(token) {
    if (typeof token !== 'string' || token.length === 0 || token.length > 200) return null;
    const session = this.store.findSession(token);
    if (!session) return null;
    if (session.expiresAt <= this.now()) {
      this.store.removeSession(token);
      return null;
    }
    return this.store.users.get(session.userId) ?? null;
  }

  // #docregion session
  _startSession(user) {
    // 32 random bytes from the operating system's secure generator.
    const token = randomBytes(32).toString('base64url');
    const expiresAt = this.now() + this.tokenTtlMs;
    this.store.addSession(token, user.id, expiresAt);
    return ok({ user: { id: user.id, username: user.username }, token, expiresAt });
  }
  // #enddocregion session
}

module.exports = { Auth };
