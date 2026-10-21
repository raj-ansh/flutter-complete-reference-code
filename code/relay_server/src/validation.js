'use strict';
// Every value that arrives from a client is checked here, on the server. The
// client may check too, for friendlier messages, but the server never relies on it.

const LIMITS = Object.freeze({
  usernameMin: 3,
  usernameMax: 20,
  passwordMin: 10,
  passwordMax: 128,
  roomNameMax: 40,
  textMax: 2000,
  historyMax: 100,
});

// A result is either { ok: true, value } or { ok: false, message }.
const ok = (value) => ({ ok: true, value });
const bad = (message) => ({ ok: false, message });

// #docregion username
/** Lower-case letters, digits and underscore, 3 to 20 characters. */
function username(input) {
  if (typeof input !== 'string') return bad('username must be text');
  const name = input.trim().toLowerCase();
  if (name.length < LIMITS.usernameMin || name.length > LIMITS.usernameMax) {
    return bad(`username must be ${LIMITS.usernameMin} to ${LIMITS.usernameMax} characters`);
  }
  if (!/^[a-z0-9_]+$/.test(name)) {
    return bad('username may contain only letters, digits and underscore');
  }
  return ok(name);
}
// #enddocregion username

/**
 * Length is counted in characters, not bytes. Nothing else is restricted: the
 * password is hashed, never displayed, so any characters are fine (OWASP advises
 * accepting all Unicode characters and not silently shortening passwords).
 */
function password(input) {
  if (typeof input !== 'string') return bad('password must be text');
  const length = [...input].length;
  if (length < LIMITS.passwordMin) return bad(`password must be at least ${LIMITS.passwordMin} characters`);
  if (length > LIMITS.passwordMax) return bad(`password must be at most ${LIMITS.passwordMax} characters`);
  return ok(input);
}

// Control characters (including newlines and the NUL byte) have no place in names.
const CONTROL = /[\u0000-\u001f\u007f]/;

function roomName(input) {
  if (typeof input !== 'string') return bad('room name must be text');
  const name = input.trim().replace(/\s+/g, ' ');
  if (name.length === 0 || name.length > LIMITS.roomNameMax) {
    return bad(`room name must be 1 to ${LIMITS.roomNameMax} characters`);
  }
  if (CONTROL.test(name)) return bad('room name contains invalid characters');
  return ok(name);
}

function messageText(input) {
  if (typeof input !== 'string') return bad('message must be text');
  const text = input.trim();
  if (text.length === 0 || text.length > LIMITS.textMax) {
    return bad(`message must be 1 to ${LIMITS.textMax} characters`);
  }
  // Newlines and tabs are allowed in messages; other control characters are not.
  if (/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(text)) {
    return bad('message contains invalid characters');
  }
  return ok(text);
}

function id(input) {
  if (typeof input !== 'string' || !/^[a-z0-9]{8,32}$/.test(input)) return bad('invalid id');
  return ok(input);
}

function integerInRange(input, min, max, fallback) {
  if (input === undefined || input === null) return ok(fallback);
  if (!Number.isInteger(input) || input < min || input > max) {
    return bad(`must be a whole number from ${min} to ${max}`);
  }
  return ok(input);
}

module.exports = { LIMITS, username, password, roomName, messageText, id, integerInRange };
