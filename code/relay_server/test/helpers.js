'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { io: connect } = require('socket.io-client');
const { createServer } = require('../src/server');

// Cheap Argon2id settings, so the many sign-ups in these tests stay fast. The
// real defaults are tested separately in passwords.test.js.
const FAST = { memory: 8, passes: 1, parallelism: 1 };

/** Saves text that the book quotes, next to the other captured outputs. */
function capture(name, text) {
  const dir = path.join(__dirname, '..', '..', 'captured');
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, name), text.endsWith('\n') ? text : `${text}\n`);
}

async function startServer(options = {}) {
  const server = createServer({ params: FAST, ...options });
  const port = await server.start(0);
  const base = `http://127.0.0.1:${port}`;
  return { ...server, port, base };
}

async function post(base, route, body, headers = {}) {
  const res = await fetch(`${base}${route}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...headers },
    body: typeof body === 'string' ? body : JSON.stringify(body),
  });
  return { status: res.status, headers: res.headers, body: await res.json() };
}

/** Registers a user over HTTP and returns { token, user }. */
async function signUp(base, username, password = 'a long enough password') {
  const res = await post(base, '/api/register', { username, password });
  if (res.status !== 200) throw new Error(`sign-up failed: ${JSON.stringify(res.body)}`);
  return res.body;
}

/** Opens an authenticated socket and waits until it is connected. */
function open(base, token) {
  const socket = connect(base, {
    transports: ['websocket'],
    auth: { token },
    forceNew: true,
    reconnection: false,
  });
  return new Promise((resolve, reject) => {
    socket.once('connect', () => resolve(socket));
    socket.once('connect_error', (error) => {
      socket.close();
      reject(error);
    });
  });
}

/** emit with an acknowledgement, as a promise. */
function ask(socket, event, payload, timeoutMs = 3000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`no acknowledgement for ${event}`)), timeoutMs);
    socket.emit(event, payload, (reply) => {
      clearTimeout(timer);
      resolve(reply);
    });
  });
}

/** Resolves with the next payload of [event], or rejects after [timeoutMs]. */
function next(socket, event, timeoutMs = 3000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`no "${event}" event arrived`)), timeoutMs);
    socket.once(event, (payload) => {
      clearTimeout(timer);
      resolve(payload);
    });
  });
}

/** Resolves true if [event] does NOT arrive within [ms] (for "nobody hears this"). */
function silent(socket, event, ms = 300) {
  return new Promise((resolve) => {
    const handler = () => resolve(false);
    socket.once(event, handler);
    setTimeout(() => {
      socket.off(event, handler);
      resolve(true);
    }, ms);
  });
}

module.exports = { FAST, capture, startServer, post, signUp, open, ask, next, silent };
