'use strict';
// A tiny HTTPS server with a self-signed certificate, for Chapter 29.
// Usage: node server.js [port]   (prints PORT=<number> when ready)
const https = require('node:https');
const fs = require('node:fs');

const server = https.createServer(
  { key: fs.readFileSync('key.pem'), cert: fs.readFileSync('cert.pem') },
  (req, res) => {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true, secret: 'the answer is 42' }));
  },
);
server.listen(Number(process.argv[2] ?? 0), '127.0.0.1', () => {
  console.log(`PORT=${server.address().port}`);
});
