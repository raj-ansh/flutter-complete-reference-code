// Takes a screenshot of a page in headless Chrome after waiting for it to
// render, and prints what the page wrote to the console.
// Usage: node tool/shot.mjs <url> <out.png> [waitMilliseconds]
import { spawn } from 'node:child_process';
import { writeFileSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const [url, out, wait = '15000'] = process.argv.slice(2);
const chrome = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const port = 9300 + Math.floor(Math.random() * 500);
const profile = mkdtempSync(join(tmpdir(), 'shot-'));
const proc = spawn(chrome, [
  `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`, '--headless=new',
  '--disable-gpu', '--hide-scrollbars', '--window-size=900,700', 'about:blank',
], { stdio: 'ignore' });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function pageSocket() {
  for (let i = 0; i < 50; i++) {
    try {
      const targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
      const page = targets.find((t) => t.type === 'page');
      if (page) return page.webSocketDebuggerUrl;
    } catch { /* Chrome is still starting */ }
    await sleep(200);
  }
  throw new Error('Chrome did not start');
}

const ws = new WebSocket(await pageSocket());
await new Promise((r) => (ws.onopen = r));
let id = 0;
const pending = new Map();
ws.onmessage = (e) => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) pending.get(m.id)(m.result);
  if (m.method === 'Runtime.consoleAPICalled') {
    console.log('console:', m.params.args.map((a) => a.value ?? a.description).join(' ').slice(0, 300));
  }
  if (m.method === 'Runtime.exceptionThrown') {
    console.log('exception:', (m.params.exceptionDetails.exception?.description ?? m.params.exceptionDetails.text).slice(0, 300));
  }
};
const send = (method, params = {}) => new Promise((r) => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });

await send('Runtime.enable');
await send('Page.enable');
await send('Page.navigate', { url });
await sleep(Number(wait));
const shot = await send('Page.captureScreenshot', { format: 'png' });
writeFileSync(out, Buffer.from(shot.data, 'base64'));
console.log('wrote', out);
ws.close();
proc.kill();
process.exit(0);
