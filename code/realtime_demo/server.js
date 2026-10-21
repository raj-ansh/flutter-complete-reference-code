// Minimal Socket.IO server for Chapter 21. Usage: node server.js [port]
// Port 0 (the default) lets the operating system pick a free port; the chosen
// port is printed as "PORT=<number>" so a test can find it.
const http = require('node:http');
const { Server } = require('socket.io');

const MAX_TEXT = 200;
const port = Number(process.argv[2] ?? 0);

const httpServer = http.createServer();
const io = new Server(httpServer);

let nextId = 1;

io.on('connection', (socket) => {
  socket.emit('hello', { id: socket.id });

  // A client may call emit() without an acknowledgement callback, so every
  // handler must check that `ack` really is a function.
  socket.on('chat:send', (payload, ack) => {
    const reply = typeof ack === 'function' ? ack : () => {};
    const text = typeof payload?.text === 'string' ? payload.text.trim() : '';
    if (text.length === 0 || text.length > MAX_TEXT) {
      reply({ ok: false, error: `text must be 1 to ${MAX_TEXT} characters` });
      return;
    }
    const message = { id: nextId++, from: socket.id.slice(0, 5), text, at: Date.now() };
    io.emit('chat:message', message); // everyone, including the sender
    reply({ ok: true, id: message.id });
  });

  socket.on('room:join', (name, ack) => {
    const reply = typeof ack === 'function' ? ack : () => {};
    if (typeof name !== 'string' || !/^[a-z0-9-]{1,20}$/.test(name)) {
      reply({ ok: false, error: 'invalid room name' });
      return;
    }
    socket.join(name);
    reply({ ok: true });
  });

  socket.on('room:send', (payload, ack) => {
    const reply = typeof ack === 'function' ? ack : () => {};
    const room = payload?.room;
    const text = typeof payload?.text === 'string' ? payload.text.trim() : '';
    // Only members of a room may speak in it.
    if (typeof room !== 'string' || !socket.rooms.has(room) || text.length === 0) {
      reply({ ok: false, error: 'not in that room, or empty text' });
      return;
    }
    io.to(room).emit('room:message', { room, from: socket.id.slice(0, 5), text });
    reply({ ok: true });
  });
});

httpServer.listen(port, '127.0.0.1', () => {
  console.log(`PORT=${httpServer.address().port}`);
});
