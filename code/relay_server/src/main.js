'use strict';
// Usage: node src/main.js [port]      (environment: PORT, DATA_FILE)
// Prints "PORT=<number>" when ready, so that a test or script can find the port.

const { createServer } = require('./server');

const port = Number(process.argv[2] ?? process.env.PORT ?? 3000);
const server = createServer({ dataFile: process.env.DATA_FILE });

server.start(port, process.env.HOST ?? '127.0.0.1').then((actual) => {
  console.log(`PORT=${actual}`);
});

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, async () => {
    await server.stop(); // writes the data file one last time
    process.exit(0);
  });
}
