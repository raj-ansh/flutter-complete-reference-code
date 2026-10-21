'use strict';

const http = require('node:http');
const { Server } = require('socket.io');
const { Store } = require('./store');
const { Auth } = require('./auth');
const { Rooms } = require('./rooms');
const { RateLimiter } = require('./rate_limit');
const { ok, fail } = require('./results');

const STATUS = {
  invalid: 400,
  unauthorized: 401,
  forbidden: 403,
  not_found: 404,
  conflict: 409,
  rate_limited: 429,
  too_large: 413,
};

// #docregion http
/** Reads a small JSON body. Rejects big bodies and non-JSON content. */
function readJson(req, limitBytes = 4096) {
  return new Promise((resolve) => {
    if (!/^application\/json\b/i.test(req.headers['content-type'] ?? '')) {
      return resolve({ error: fail('invalid', 'Send JSON with Content-Type: application/json.') });
    }
    let size = 0;
    const chunks = [];
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > limitBytes) {
        // Stop reading. The answer goes out first; send() then closes the
        // connection, so a client cannot make the server swallow a huge upload.
        req.pause();
        resolve({ error: fail('too_large', 'Request body too large.') });
        return;
      }
      if (size <= limitBytes) chunks.push(chunk);
    });
    req.on('end', () => {
      try {
        const value = JSON.parse(Buffer.concat(chunks).toString('utf8'));
        resolve(value !== null && typeof value === 'object' && !Array.isArray(value)
          ? { value }
          : { error: fail('invalid', 'Body must be a JSON object.') });
      } catch {
        resolve({ error: fail('invalid', 'Body is not valid JSON.') });
      }
    });
    req.on('error', () => resolve({ error: fail('invalid', 'Could not read the request.') }));
  });
}

function send(res, result) {
  const status = result.ok ? 200 : (STATUS[result.code] ?? 500);
  const headers = {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store', // never let a proxy or browser keep a token
    'X-Content-Type-Options': 'nosniff',
  };
  if (result.retryAfterMs) headers['Retry-After'] = String(Math.ceil(result.retryAfterMs / 1000));
  if (result.code === 'too_large') headers.Connection = 'close';
  res.writeHead(status, headers);
  res.end(JSON.stringify(result));
  if (result.code === 'too_large') res.on('finish', () => res.req.destroy());
}
// #enddocregion http

/**
 * Builds the server. Nothing listens until start() is called.
 * @param {{ dataFile?: string, params?: object, now?: () => number,
 *           registerBurst?: number, loginBurst?: number }} options
 */
function createServer(options = {}) {
  const store = new Store({ dataFile: options.dataFile });
  const auth = new Auth(store, {
    now: options.now,
    params: options.params,
    registerBurst: options.registerBurst,
    loginBurst: options.loginBurst,
  });
  const rooms = new Rooms(store, { now: options.now });
  const online = new Map(); // userId -> number of connected sockets

  const httpServer = http.createServer(async (req, res) => {
    const url = new URL(req.url ?? '/', 'http://localhost');
    // The key for rate limiting is the connecting address. Behind a proxy this
    // would be the proxy: configure the proxy to pass the real address, and
    // only then trust it.
    const client = req.socket.remoteAddress ?? 'unknown';

    if (req.method === 'GET' && url.pathname === '/api/health') return send(res, ok({ status: 'up' }));

    if (req.method === 'POST' && ['/api/register', '/api/login', '/api/logout'].includes(url.pathname)) {
      const body = await readJson(req);
      if (body.error) return send(res, body.error);
      if (url.pathname === '/api/register') return send(res, await auth.register(body.value, client));
      if (url.pathname === '/api/login') return send(res, await auth.login(body.value, client));
      const bearer = /^Bearer (\S+)$/.exec(req.headers.authorization ?? '');
      return send(res, auth.logout(bearer?.[1]));
    }
    // socket.io answers its own paths before this handler is reached.
    send(res, fail('not_found', 'Not found.'));
  });

  const io = new Server(httpServer, {
    maxHttpBufferSize: 16 * 1024, // no single message above 16 KiB
    connectTimeout: 10_000,
  });

  // #docregion socketauth
  io.use((socket, next) => {
    const token = socket.handshake.auth?.token;
    const user = auth.authenticate(token);
    if (!user) return next(new Error('unauthorized'));
    socket.data.user = user;
    socket.data.token = token;
    next();
  });
  // #enddocregion socketauth

  const general = new RateLimiter({ capacity: 30, refillPerSecond: 10, now: options.now });
  const sending = new RateLimiter({ capacity: 10, refillPerSecond: 2, now: options.now });

  const userChannel = (id) => `user:${id}`;
  const roomChannel = (id) => `room:${id}`;

  io.on('connection', (socket) => {
    const user = socket.data.user;
    online.set(user.id, (online.get(user.id) ?? 0) + 1);
    // Every socket of a user (phone and tablet, say) joins that user's own
    // channel and the channels of the rooms they belong to.
    socket.join(userChannel(user.id));
    for (const roomId of rooms.roomIdsOf(user.id)) socket.join(roomChannel(roomId));
    socket.emit('hello', { user: { id: user.id, username: user.username } });

    socket.on('disconnect', () => {
      const left = (online.get(user.id) ?? 1) - 1;
      if (left <= 0) online.delete(user.id);
      else online.set(user.id, left);
    });

    // #docregion handle
    /**
     * Wraps every event with the same protections: a guaranteed callback, a
     * check that the session is still valid, rate limiting, and a catch-all so
     * that a bug in one handler cannot crash the server.
     */
    function handle(event, action, limiter = general) {
      socket.on(event, (payload, ack) => {
        // A client may omit the callback; never call something that is not a function.
        const reply = typeof ack === 'function' ? ack : () => {};
        try {
          if (!auth.authenticate(socket.data.token)) {
            socket.emit('session:expired');
            reply(fail('unauthorized', 'Your session has ended. Sign in again.'));
            socket.disconnect(true);
            return;
          }
          const gate = limiter.take(user.id);
          if (!gate.allowed) {
            return reply(fail('rate_limited', 'Slow down.', { retryAfterMs: gate.retryAfterMs }));
          }
          const args = payload !== null && typeof payload === 'object' && !Array.isArray(payload) ? payload : {};
          reply(action(args));
        } catch (error) {
          console.error(`[relay] ${event} failed:`, error);
          reply(fail('internal', 'Something went wrong on the server.'));
        }
      });
    }
    // #enddocregion handle

    handle('rooms:list', () => rooms.list(user.id));

    handle('room:create', (p) => {
      const result = rooms.create(user.id, p);
      if (result.ok) io.in(userChannel(user.id)).socketsJoin(roomChannel(result.room.id));
      return result;
    });

    handle('room:join', (p) => {
      const result = rooms.join(user.id, p.roomId);
      if (result.ok) {
        io.in(userChannel(user.id)).socketsJoin(roomChannel(result.room.id));
        io.to(roomChannel(result.room.id)).emit('room:changed', {
          roomId: result.room.id, reason: 'joined', username: user.username,
        });
      }
      return result;
    });

    handle('room:leave', (p) => {
      const result = rooms.leave(user.id, p.roomId);
      if (result.ok) {
        io.in(userChannel(user.id)).socketsLeave(roomChannel(p.roomId));
        io.to(roomChannel(p.roomId)).emit('room:changed', {
          roomId: p.roomId, reason: 'left', username: user.username,
        });
      }
      return result;
    });

    handle('room:invite', (p) => {
      const result = rooms.invite(user.id, p.roomId, p.username);
      if (result.ok) {
        // Delivered to the invited user's own channel: all of their devices
        // hear it, nobody else does.
        io.to(userChannel(result.targetId)).emit('invite:received', {
          room: result.room, from: user.username,
        });
      }
      return ok();
    });

    handle('room:kick', (p) => {
      const result = rooms.kick(user.id, p.roomId, p.username);
      if (result.ok) {
        io.in(userChannel(result.targetId)).socketsLeave(roomChannel(p.roomId));
        io.to(userChannel(result.targetId)).emit('room:kicked', { roomId: p.roomId });
        io.to(roomChannel(p.roomId)).emit('room:changed', {
          roomId: p.roomId, reason: 'removed', username: String(p.username).trim().toLowerCase(),
        });
      }
      return result.ok ? ok() : result;
    });

    handle('room:close', (p) => {
      const result = rooms.close(user.id, p.roomId);
      if (result.ok) {
        io.to(roomChannel(p.roomId)).emit('room:closed', { roomId: p.roomId });
        io.in(roomChannel(p.roomId)).socketsLeave(roomChannel(p.roomId));
      }
      return result.ok ? ok() : result;
    });

    handle('room:send', (p) => {
      const result = rooms.send(user.id, p.roomId, p.text);
      if (result.ok) io.to(roomChannel(p.roomId)).emit('room:message', result.message);
      return result;
    }, sending);

    handle('room:history', (p) => rooms.history(user.id, p.roomId, p));

    handle('room:members', (p) => {
      const result = rooms.members(user.id, p.roomId);
      if (!result.ok) return result;
      return ok({ members: result.members.map((m) => ({ ...m, online: online.has(m.id) })) });
    });
  });

  return {
    store, auth, rooms, io, httpServer,
    /** Starts listening on 127.0.0.1 (port 0 picks a free one) and returns the port. */
    start(port = 0, host = '127.0.0.1') {
      return new Promise((resolve) => httpServer.listen(port, host, () => resolve(httpServer.address().port)));
    },
    async stop() {
      store.trySave();
      await io.close(); // also closes the http server
    },
  };
}

module.exports = { createServer };
