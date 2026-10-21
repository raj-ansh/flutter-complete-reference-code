'use strict';
// Password hashing with Argon2id, built into Node.js since v24.7.0.

const { argon2, randomBytes, timingSafeEqual } = require('node:crypto');
const { promisify } = require('node:util');

// The asynchronous form runs on a worker thread, so hashing (deliberately slow)
// does not freeze the server for everyone else while it works.
const argon2Async = promisify(argon2);

// #docregion params
// OWASP's Password Storage Cheat Sheet lists Argon2id with at least
// m = 19456 KiB (19 MiB), t = 2 iterations, p = 1 as a minimum configuration.
const DEFAULT_PARAMS = Object.freeze({ memory: 19456, passes: 2, parallelism: 1 });
const SALT_BYTES = 16; // Node's documentation recommends at least 16 random bytes
const HASH_BYTES = 32;
// #enddocregion params

const b64 = (buffer) => buffer.toString('base64');

// #docregion hash
/**
 * Returns a self-describing string:
 *   argon2id$m=19456,t=2,p=1$<salt>$<hash>
 * The parameters are stored with the hash, so they can be raised later and old
 * hashes still verify.
 */
async function hashPassword(password, params = DEFAULT_PARAMS) {
  const salt = randomBytes(SALT_BYTES); // a new random salt for every password
  const hash = await argon2Async('argon2id', {
    message: Buffer.from(password, 'utf8'),
    nonce: salt,
    parallelism: params.parallelism,
    tagLength: HASH_BYTES,
    memory: params.memory,
    passes: params.passes,
  });
  return `argon2id$m=${params.memory},t=${params.passes},p=${params.parallelism}$${b64(salt)}$${b64(hash)}`;
}
// #enddocregion hash

function parse(stored) {
  const parts = typeof stored === 'string' ? stored.split('$') : [];
  if (parts.length !== 4 || parts[0] !== 'argon2id') return null;
  const match = /^m=(\d+),t=(\d+),p=(\d+)$/.exec(parts[1]);
  if (!match) return null;
  return {
    params: { memory: Number(match[1]), passes: Number(match[2]), parallelism: Number(match[3]) },
    salt: Buffer.from(parts[2], 'base64'),
    hash: Buffer.from(parts[3], 'base64'),
  };
}

// #docregion verify
/** True if [password] matches [stored]. Never throws for bad stored data. */
async function verifyPassword(password, stored) {
  const record = parse(stored);
  if (!record) return false;
  let candidate;
  try {
    candidate = await argon2Async('argon2id', {
      message: Buffer.from(password, 'utf8'),
      nonce: record.salt,
      parallelism: record.params.parallelism,
      tagLength: record.hash.length,
      memory: record.params.memory,
      passes: record.params.passes,
    });
  } catch {
    return false;
  }
  // Compare in constant time, so the time taken does not reveal how many
  // leading bytes matched. timingSafeEqual requires equal lengths.
  return candidate.length === record.hash.length && timingSafeEqual(candidate, record.hash);
}
// #enddocregion verify

/** Should this stored hash be recomputed with stronger parameters? */
function needsRehash(stored, wanted = DEFAULT_PARAMS) {
  const record = parse(stored);
  if (!record) return true;
  const p = record.params;
  return p.memory < wanted.memory || p.passes < wanted.passes || p.parallelism < wanted.parallelism;
}

module.exports = { DEFAULT_PARAMS, hashPassword, verifyPassword, needsRehash };
