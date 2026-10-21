'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { startServer, signUp, open, ask, next, silent, capture } = require('./helpers');

/** A server, plus a helper that signs a user up and opens one socket for them. */
async function setup(t, options) {
  const s = await startServer(options);
  const sockets = [];
  t.after(async () => {
    for (const socket of sockets) socket.close();
    await s.stop();
  });
  async function user(name) {
    const { token, user: u } = await signUp(s.base, name);
    const socket = await open(s.base, token);
    sockets.push(socket);
    return { name, id: u.id, token, socket };
  }
  async function device(person) {
    const socket = await open(s.base, person.token); // a second device, same account
    sockets.push(socket);
    return socket;
  }
  return { s, user, device };
}

test('a conversation: create, join, send, everyone in the room hears it', async (t) => {
  const { user } = await setup(t);
  const [alice, bob, dave] = [await user('alice'), await user('bob'), await user('dave')];
  const log = [];

  const created = await ask(alice.socket, 'room:create', { name: 'Garden club', isPublic: true });
  assert.equal(created.ok, true);
  const roomId = created.room.id;

  const list = await ask(bob.socket, 'rooms:list', {});
  assert.deepEqual(list.rooms.map((r) => [r.name, r.joined]), [['Garden club', false]]);
  const joined = await ask(bob.socket, 'room:join', { roomId });
  assert.equal(joined.ok, true);

  const heardByAlice = next(alice.socket, 'room:message');
  const heardByBob = next(bob.socket, 'room:message');
  const daveSilent = silent(dave.socket, 'room:message');
  const sent = await ask(alice.socket, 'room:send', { roomId, text: '  Water the basil!  ' });
  const [a, b] = await Promise.all([heardByAlice, heardByBob]);

  assert.equal(sent.ok, true);
  assert.equal(a.text, 'Water the basil!'); // trimmed by the server
  assert.equal(a.username, 'alice'); // taken from the session, not from the client
  assert.equal(a.seq, 1);
  assert.deepEqual(b, a);
  assert.equal(await daveSilent, true, 'a user outside the room hears nothing');

  log.push(`alice sends "  Water the basil!  "  -> ack: ok, seq ${sent.message.seq}`);
  log.push(`alice receives: ${a.username}: "${a.text}" (seq ${a.seq})`);
  log.push(`bob receives:   ${b.username}: "${b.text}" (seq ${b.seq})`);
  log.push('dave, not in the room, receives nothing');
  capture('relay_conversation.txt', log.join('\n'));
});

test('a client cannot forge who it is, the sequence number or the time', async (t) => {
  const { user } = await setup(t);
  const alice = await user('alice');
  const bob = await user('bob');
  const { room } = await ask(alice.socket, 'room:create', { name: 'Forgery', isPublic: true });
  await ask(bob.socket, 'room:join', { roomId: room.id });
  const heard = next(bob.socket, 'room:message');
  await ask(alice.socket, 'room:send', {
    roomId: room.id, text: 'honest text', username: 'bob', userId: bob.id, seq: 999, at: 0,
  });
  const message = await heard;
  assert.equal(message.username, 'alice');
  assert.equal(message.userId, alice.id);
  assert.equal(message.seq, 1);
  assert.ok(message.at > 1_000_000_000_000);
});

test('a private room: invisible, then reachable only through an invitation', async (t) => {
  const { user } = await setup(t);
  const [alice, bob, carol] = [await user('alice'), await user('bob'), await user('carol')];
  const { room } = await ask(alice.socket, 'room:create', { name: 'Plans', isPublic: false });
  const log = [];

  const asBob = async (event, payload) => (await ask(bob.socket, event, payload));
  const visible = (await asBob('rooms:list', {})).rooms.length;
  const tryJoin = await asBob('room:join', { roomId: room.id });
  const trySend = await asBob('room:send', { roomId: room.id, text: 'let me in' });
  log.push(`bob sees ${visible} rooms; join -> ${tryJoin.code}; send -> ${trySend.code}`);
  assert.equal(visible, 0);
  assert.equal(tryJoin.code, 'not_found');
  assert.equal(trySend.code, 'not_found');

  const invited = next(bob.socket, 'invite:received');
  assert.equal((await ask(alice.socket, 'room:invite', { roomId: room.id, username: 'Bob' })).ok, true);
  const invite = await invited;
  assert.equal(invite.from, 'alice');
  assert.equal(invite.room.name, 'Plans');
  log.push(`alice invites bob -> bob's device receives: invitation to "${invite.room.name}" from ${invite.from}`);

  const carolSilent = silent(carol.socket, 'invite:received');
  assert.equal(await carolSilent, true, 'only the invited user is told');
  log.push('carol, who was not invited, receives nothing');

  assert.equal((await asBob('room:join', { roomId: room.id })).ok, true);
  const heard = next(bob.socket, 'room:message');
  await ask(alice.socket, 'room:send', { roomId: room.id, text: 'welcome' });
  assert.equal((await heard).text, 'welcome');
  log.push('bob accepts (joins), and now receives the room\'s messages');
  capture('relay_private_room.txt', log.join('\n'));
});

test('per-user delivery: every device of the invited user hears, nobody else', async (t) => {
  const { user, device } = await setup(t);
  const [alice, bob] = [await user('alice'), await user('bob')];
  const bobTablet = await device(bob);
  const { room } = await ask(alice.socket, 'room:create', { name: 'Two devices', isPublic: false });

  const phone = next(bob.socket, 'invite:received');
  const tablet = next(bobTablet, 'invite:received');
  const aliceSilent = silent(alice.socket, 'invite:received');
  await ask(alice.socket, 'room:invite', { roomId: room.id, username: 'bob' });
  assert.equal((await phone).room.id, room.id);
  assert.equal((await tablet).room.id, room.id);
  assert.equal(await aliceSilent, true);

  // Joining on the phone also subscribes the tablet to the room's messages.
  await ask(bob.socket, 'room:join', { roomId: room.id });
  const onTablet = next(bobTablet, 'room:message');
  await ask(alice.socket, 'room:send', { roomId: room.id, text: 'to both' });
  assert.equal((await onTablet).text, 'to both');
});

test('kicking: the target is told, stops receiving, and cannot return uninvited', async (t) => {
  const { user, device } = await setup(t);
  const [alice, bob, carol] = [await user('alice'), await user('bob'), await user('carol')];
  const bobTablet = await device(bob);
  const { room } = await ask(alice.socket, 'room:create', { name: 'Strict', isPublic: false });
  for (const who of [bob, carol]) {
    await ask(alice.socket, 'room:invite', { roomId: room.id, username: who.name });
    await ask(who.socket, 'room:join', { roomId: room.id });
  }
  const log = [];

  // A member may not kick; a stranger to the room learns nothing.
  const byMember = await ask(carol.socket, 'room:kick', { roomId: room.id, username: 'bob' });
  log.push(`carol (a member) tries to remove bob -> ${byMember.code}`);
  assert.equal(byMember.code, 'forbidden');

  const told = next(bob.socket, 'room:kicked');
  const toldTablet = next(bobTablet, 'room:kicked');
  const others = next(carol.socket, 'room:changed');
  const result = await ask(alice.socket, 'room:kick', { roomId: room.id, username: 'bob' });
  assert.equal(result.ok, true);
  assert.equal((await told).roomId, room.id);
  assert.equal((await toldTablet).roomId, room.id);
  const change = await others;
  assert.deepEqual([change.reason, change.username], ['removed', 'bob']);
  log.push('alice removes bob -> bob (both devices) receive room:kicked; carol receives room:changed (removed, bob)');

  const bobSilent = silent(bob.socket, 'room:message');
  const tabletSilent = silent(bobTablet, 'room:message');
  await ask(alice.socket, 'room:send', { roomId: room.id, text: 'after the removal' });
  assert.equal(await bobSilent, true);
  assert.equal(await tabletSilent, true);
  log.push('a message sent afterwards reaches neither of bob\'s devices');

  const back = await ask(bob.socket, 'room:join', { roomId: room.id });
  log.push(`bob tries to come back without a new invitation -> ${back.code}`);
  assert.equal(back.code, 'not_found');
  capture('relay_kick.txt', log.join('\n'));
});

test('closing a room tells everyone and ends it', async (t) => {
  const { user } = await setup(t);
  const [alice, bob] = [await user('alice'), await user('bob')];
  const { room } = await ask(alice.socket, 'room:create', { name: 'Temporary', isPublic: true });
  await ask(bob.socket, 'room:join', { roomId: room.id });

  assert.equal((await ask(bob.socket, 'room:close', { roomId: room.id })).code, 'forbidden');
  const told = next(bob.socket, 'room:closed');
  assert.equal((await ask(alice.socket, 'room:close', { roomId: room.id })).ok, true);
  assert.equal((await told).roomId, room.id);
  assert.equal((await ask(bob.socket, 'room:send', { roomId: room.id, text: 'hello?' })).code, 'not_found');
  assert.deepEqual((await ask(bob.socket, 'rooms:list', {})).rooms, []);
});

test('reconnecting: a client catches up with history after its last sequence number', async (t) => {
  const { s, user } = await setup(t);
  const alice = await user('alice');
  const bob = await user('bob');
  const { room } = await ask(alice.socket, 'room:create', { name: 'Catch up', isPublic: true });
  await ask(bob.socket, 'room:join', { roomId: room.id });
  await ask(alice.socket, 'room:send', { roomId: room.id, text: 'one' });
  await ask(alice.socket, 'room:send', { roomId: room.id, text: 'two' });

  bob.socket.close(); // bob goes offline
  await ask(alice.socket, 'room:send', { roomId: room.id, text: 'three' });
  await ask(alice.socket, 'room:send', { roomId: room.id, text: 'four' });

  const back = await open(s.base, bob.token); // bob reconnects, still a member
  t.after(() => back.close());
  const missed = await ask(back, 'room:history', { roomId: room.id, afterSeq: 2 });
  assert.deepEqual(missed.messages.map((m) => [m.seq, m.text]), [[3, 'three'], [4, 'four']]);

  // And the live channel works again without joining again.
  const live = next(back, 'room:message');
  await ask(alice.socket, 'room:send', { roomId: room.id, text: 'five' });
  assert.equal((await live).seq, 5);
  capture(
    'relay_catch_up.txt',
    'bob saw seq 1 and 2, went offline, and alice sent two more.\n' +
      `after reconnecting, history(afterSeq: 2) returned: ${missed.messages.map((m) => `#${m.seq} "${m.text}"`).join(', ')}\n` +
      'the next live message arrived as #5, with no gap.',
  );
});

test('members list shows who is online', async (t) => {
  const { user } = await setup(t);
  const alice = await user('alice');
  const bob = await user('bob');
  const { room } = await ask(alice.socket, 'room:create', { name: 'Presence', isPublic: true });
  await ask(bob.socket, 'room:join', { roomId: room.id });
  let members = (await ask(alice.socket, 'room:members', { roomId: room.id })).members;
  assert.deepEqual(members.map((m) => [m.username, m.isOwner, m.online]), [['alice', true, true], ['bob', false, true]]);
  bob.socket.close();
  await new Promise((r) => setTimeout(r, 100));
  members = (await ask(alice.socket, 'room:members', { roomId: room.id })).members;
  assert.deepEqual(members.map((m) => m.online), [true, false]);
});

test('hostile or sloppy clients: bad payloads, no callbacks, oversized messages', async (t) => {
  const { s, user } = await setup(t);
  const alice = await user('alice');
  const { room } = await ask(alice.socket, 'room:create', { name: 'Robust', isPublic: true });
  const rows = [];

  for (const [label, payload] of [
    ['null', null],
    ['a string', 'text'],
    ['an array', [1, 2]],
    ['a number', 42],
    ['an object with wrong types', { roomId: 5, text: { a: 1 } }],
    ['an unknown room id', { roomId: '../../etc/passwd', text: 'x' }],
    ['text over the limit', { roomId: room.id, text: 'x'.repeat(2001) }],
  ]) {
    const reply = await ask(alice.socket, 'room:send', payload);
    rows.push(`room:send with ${label.padEnd(26)} -> ${reply.ok ? 'ok' : `${reply.code}: ${reply.message}`}`);
    assert.equal(reply.ok, false, label);
  }

  // No acknowledgement callback at all: the server must not crash.
  alice.socket.emit('room:send', { roomId: room.id, text: 'no callback' });
  alice.socket.emit('room:send');
  alice.socket.emit('no:such:event', { anything: true });
  await new Promise((r) => setTimeout(r, 200));
  assert.equal((await ask(alice.socket, 'rooms:list', {})).ok, true, 'the server is still serving');
  rows.push('emits without a callback, with no payload, and with an unknown event name: server still answers');

  // A message beyond the transport's size limit closes the connection.
  const closed = new Promise((resolve) => alice.socket.once('disconnect', resolve));
  alice.socket.emit('room:send', { roomId: room.id, text: 'y'.repeat(40_000) });
  const reason = await closed;
  rows.push(`a 40,000-character message: connection closed by the server (${reason})`);
  assert.equal((await fetch(`${s.base}/api/health`)).status, 200, 'the server itself is fine');
  capture('relay_hostile_input.txt', rows.join('\n'));
});

test('sending is rate limited per user', async (t) => {
  const { user } = await setup(t);
  const alice = await user('alice');
  const { room } = await ask(alice.socket, 'room:create', { name: 'Flood', isPublic: true });
  const codes = [];
  for (let i = 0; i < 14; i++) {
    const reply = await ask(alice.socket, 'room:send', { roomId: room.id, text: `m${i}` });
    codes.push(reply.ok ? 'ok' : reply.code);
  }
  assert.equal(codes.filter((c) => c === 'ok').length >= 10, true);
  assert.ok(codes.includes('rate_limited'));
  capture('relay_send_limit.txt', `14 messages sent as fast as possible:\n${codes.join(' ')}`);
});

test('a session that expires while connected is ended on the next request', async (t) => {
  let now = 10_000_000;
  const { s, user } = await setup(t, { now: () => now });
  const alice = await user('alice');
  assert.equal((await ask(alice.socket, 'rooms:list', {})).ok, true);
  const expired = next(alice.socket, 'session:expired');
  const closed = new Promise((resolve) => alice.socket.once('disconnect', resolve));
  now += 8 * 24 * 60 * 60 * 1000;
  const reply = await ask(alice.socket, 'rooms:list', {});
  assert.equal(reply.code, 'unauthorized');
  await expired;
  await closed;
  assert.equal(s.store.sessions.size, 0);
});

test('state survives a restart of the server', async (t) => {
  const fs = require('node:fs');
  const os = require('node:os');
  const path = require('node:path');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'relay-restart-'));
  const dataFile = path.join(dir, 'data.json');

  const first = await startServer({ dataFile });
  const { token } = await signUp(first.base, 'alice');
  const socket = await open(first.base, token);
  const { room } = await ask(socket, 'room:create', { name: 'Durable', isPublic: true });
  await ask(socket, 'room:send', { roomId: room.id, text: 'remember me' });
  socket.close();
  await first.stop();

  const second = await startServer({ dataFile });
  t.after(() => second.stop());
  const again = await open(second.base, token); // the same token still works
  t.after(() => again.close());
  const history = await ask(again, 'room:history', { roomId: room.id });
  assert.equal(history.messages[0].text, 'remember me');
  t.after(() => fs.rmSync(dir, { recursive: true, force: true })); // last, after the servers stop
});

test('a failing disk does not take the server down', async (t) => {
  const fs = require('node:fs');
  const os = require('node:os');
  const path = require('node:path');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'relay-nodisk-'));
  const s = await startServer({ dataFile: path.join(dir, 'gone', 'data.json') }); // folder does not exist
  t.after(() => s.stop());
  const errors = [];
  const original = console.error;
  console.error = (...args) => errors.push(args.join(' '));
  try {
    await signUp(s.base, 'alice'); // triggers a save attempt that cannot succeed
    await new Promise((r) => setTimeout(r, 400));
  } finally {
    console.error = original;
    fs.rmSync(dir, { recursive: true, force: true });
  }
  assert.ok(errors.some((e) => e.includes('could not save the data file')), errors.join('|'));
  assert.equal((await fetch(`${s.base}/api/health`)).status, 200); // still serving
});
