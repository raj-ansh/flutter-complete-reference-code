'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { Store } = require('../src/store');
const { Rooms, KEEP_MESSAGES } = require('../src/rooms');
const { capture } = require('./helpers');

/** A store with four users and two rooms (one public, one private). */
function world() {
  const store = new Store();
  const user = (username) => store.addUser({ username, passwordHash: 'x' });
  const people = {
    alice: user('alice'), // owns both rooms
    bob: user('bob'), // a member of both
    carol: user('carol'), // invited to both
    dave: user('dave'), // has no link to either
    eve: user('eve'), // only ever the target of invitations
  };
  let clock = 1_000;
  const rooms = new Rooms(store, { now: () => (clock += 1) });
  const created = {};
  for (const [key, isPublic] of [['public', true], ['private', false]]) {
    const r = rooms.create(people.alice.id, { name: `${key} room`, isPublic });
    created[key] = r.room.id;
    rooms.invite(people.alice.id, r.room.id, 'bob');
    rooms.join(people.bob.id, r.room.id);
    rooms.invite(people.alice.id, r.room.id, 'carol');
  }
  return { store, rooms, people, ids: created };
}

const ACTORS = ['alice', 'bob', 'carol', 'dave'];
const ROLE = { alice: 'owner', bob: 'member', carol: 'invited', dave: 'outsider' };

const ACTIONS = {
  join: (w, who, room) => w.rooms.join(w.people[who].id, room),
  send: (w, who, room) => w.rooms.send(w.people[who].id, room, 'hello'),
  history: (w, who, room) => w.rooms.history(w.people[who].id, room),
  members: (w, who, room) => w.rooms.members(w.people[who].id, room),
  invite: (w, who, room) => w.rooms.invite(w.people[who].id, room, 'eve'),
  kick: (w, who, room) => w.rooms.kick(w.people[who].id, room, 'bob'),
  close: (w, who, room) => w.rooms.close(w.people[who].id, room),
  leave: (w, who, room) => w.rooms.leave(w.people[who].id, room),
};

// The rules, written as data. Each row lists the outcome for alice, bob, carol, dave.
// ok = allowed, no = forbidden, 404 = not_found.
const EXPECTED = {
  public: {
    join: ['ok', 'ok', 'ok', 'ok'],
    send: ['ok', 'ok', 'no', 'no'],
    history: ['ok', 'ok', 'no', 'no'],
    members: ['ok', 'ok', 'no', 'no'],
    invite: ['ok', 'ok', 'no', 'no'],
    kick: ['ok', 'no', 'no', 'no'],
    close: ['ok', 'no', 'no', 'no'],
    leave: ['no', 'ok', 'no', 'no'],
  },
  private: {
    join: ['ok', 'ok', 'ok', '404'],
    send: ['ok', 'ok', 'no', '404'],
    history: ['ok', 'ok', 'no', '404'],
    members: ['ok', 'ok', 'no', '404'],
    invite: ['ok', 'ok', 'no', '404'],
    kick: ['ok', 'no', 'no', '404'],
    close: ['ok', 'no', 'no', '404'],
    leave: ['no', 'ok', 'no', '404'],
  },
};

const short = (r) => (r.ok ? 'ok' : r.code === 'forbidden' ? 'no' : r.code === 'not_found' ? '404' : r.code);

test('the authorization matrix: who may do what, in public and private rooms', () => {
  const lines = [];
  for (const kind of ['public', 'private']) {
    lines.push(`${kind.toUpperCase()} ROOM (alice owns it, bob is a member, carol is invited, dave is a stranger)`);
    lines.push(`${''.padEnd(9)}${ACTORS.map((a) => `${a}(${ROLE[a]})`.padEnd(16)).join('')}`);
    for (const action of Object.keys(ACTIONS)) {
      const outcomes = ACTORS.map((who) => {
        const w = world(); // a fresh world for every cell: actions change state
        return short(ACTIONS[action](w, who, w.ids[kind]));
      });
      lines.push(`${action.padEnd(9)}${outcomes.map((o) => o.padEnd(16)).join('')}`);
      assert.deepEqual(outcomes, EXPECTED[kind][action], `${kind} room, ${action}`);
    }
    lines.push('');
  }
  lines.push('ok = allowed   no = refused (forbidden)   404 = refused as if the room did not exist');
  capture('relay_authorization.txt', lines.join('\n'));
});

test('a private room is invisible to strangers, a public one is listed', () => {
  const w = world();
  const names = (who) => w.rooms.list(w.people[who].id).rooms.map((r) => r.name).sort();
  assert.deepEqual(names('alice'), ['private room', 'public room']);
  assert.deepEqual(names('carol'), ['private room', 'public room']); // invited
  assert.deepEqual(names('dave'), ['public room']);
  // Even the error for a malformed id is the same, so ids cannot be probed.
  assert.equal(w.rooms.join(w.people.dave.id, 'nope').code, 'not_found');
  assert.equal(w.rooms.join(w.people.dave.id, w.ids.private).code, 'not_found');
  assert.equal(w.rooms.join(w.people.dave.id, '0123456789abcdef').code, 'not_found');
});

test('an invitation is used up when accepted; being kicked removes membership and invitation', () => {
  const w = world();
  const room = w.store.rooms.get(w.ids.private);
  assert.ok(room.invited.has(w.people.carol.id));
  w.rooms.join(w.people.carol.id, w.ids.private);
  assert.ok(room.members.has(w.people.carol.id));
  assert.ok(!room.invited.has(w.people.carol.id));
  w.rooms.kick(w.people.alice.id, w.ids.private, 'carol');
  assert.ok(!room.members.has(w.people.carol.id));
  // Kicked, she cannot just walk back in: the invitation was spent.
  assert.equal(w.rooms.join(w.people.carol.id, w.ids.private).code, 'not_found');
});

test('invite and kick check their targets', () => {
  const w = world();
  const a = w.people.alice.id;
  assert.equal(w.rooms.invite(a, w.ids.public, 'nobody').code, 'not_found');
  assert.equal(w.rooms.invite(a, w.ids.public, 'bob').code, 'conflict'); // already in
  assert.equal(w.rooms.invite(a, w.ids.public, 42).code, 'not_found');
  assert.equal(w.rooms.kick(a, w.ids.public, 'alice').code, 'invalid'); // not yourself
  assert.equal(w.rooms.kick(a, w.ids.public, 'dave').code, 'not_found'); // not a member
});

test('closing a room ends it for everybody and reports who was in it', () => {
  const w = world();
  const closed = w.rooms.close(w.people.alice.id, w.ids.public);
  assert.equal(closed.ok, true);
  assert.deepEqual(closed.memberIds.sort(), [w.people.alice.id, w.people.bob.id].sort());
  for (const who of ['alice', 'bob', 'carol', 'dave']) {
    assert.equal(w.rooms.send(w.people[who].id, w.ids.public, 'x').code, 'not_found', who);
  }
  assert.deepEqual(w.rooms.list(w.people.dave.id).rooms.map((r) => r.name), []);
});

test('messages get server-chosen sequence numbers; history can catch up', () => {
  const w = world();
  const [a, b] = [w.people.alice.id, w.people.bob.id];
  for (let i = 1; i <= 5; i++) w.rooms.send(i % 2 ? a : b, w.ids.public, `m${i}`);
  const all = w.rooms.history(a, w.ids.public).messages;
  assert.deepEqual(all.map((m) => m.seq), [1, 2, 3, 4, 5]);
  assert.deepEqual(all.map((m) => m.username), ['alice', 'bob', 'alice', 'bob', 'alice']);
  assert.deepEqual(w.rooms.history(a, w.ids.public, { limit: 2 }).messages.map((m) => m.text), ['m4', 'm5']);
  assert.deepEqual(w.rooms.history(a, w.ids.public, { afterSeq: 3 }).messages.map((m) => m.text), ['m4', 'm5']);
  assert.deepEqual(w.rooms.history(a, w.ids.public, { afterSeq: 5 }).messages, []);
  for (const bad of [{ limit: 0 }, { limit: 101 }, { limit: 'many' }, { afterSeq: -1 }, { afterSeq: 1.5 }]) {
    assert.equal(w.rooms.history(a, w.ids.public, bad).code, 'invalid', JSON.stringify(bad));
  }
});

test('the history is capped, but sequence numbers keep counting', () => {
  const w = world();
  const a = w.people.alice.id;
  for (let i = 0; i < KEEP_MESSAGES + 20; i++) w.rooms.send(a, w.ids.public, `m${i}`);
  const kept = w.store.rooms.get(w.ids.public).messages;
  assert.equal(kept.length, KEEP_MESSAGES);
  assert.equal(kept[0].seq, 21);
  assert.equal(kept.at(-1).seq, KEEP_MESSAGES + 20);
});

test('inputs are validated before anything changes', () => {
  const w = world();
  const a = w.people.alice.id;
  assert.equal(w.rooms.create(a, { name: '', isPublic: true }).code, 'invalid');
  assert.equal(w.rooms.create(a, { name: 'ok', isPublic: 'yes' }).code, 'invalid');
  assert.equal(w.rooms.create(a, undefined).code, 'invalid');
  assert.equal(w.rooms.send(a, w.ids.public, '   ').code, 'invalid');
  assert.equal(w.rooms.send(a, w.ids.public, 'x'.repeat(2001)).code, 'invalid');
  assert.equal(w.rooms.send(a, w.ids.public, { text: 'object' }).code, 'invalid');
  assert.equal(w.store.rooms.get(w.ids.public).messages.length, 0);
});

test('the stored data can be saved and loaded again', async () => {
  const fs = require('node:fs');
  const os = require('node:os');
  const path = require('node:path');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'relay-'));
  try {
    const file = path.join(dir, 'data.json');
    const first = new Store({ dataFile: file });
    const alice = first.addUser({ username: 'alice', passwordHash: 'hash' });
    const rooms = new Rooms(first);
    const created = rooms.create(alice.id, { name: 'Persisted', isPublic: true });
    rooms.send(alice.id, created.room.id, 'still here');
    first.addSession('a-token', alice.id, Date.now() + 60_000);
    first.saveNow();

    const second = new Store({ dataFile: file });
    const loaded = new Rooms(second);
    assert.equal(second.findUserByName('alice').id, alice.id);
    assert.equal(loaded.history(alice.id, created.room.id).messages[0].text, 'still here');
    assert.equal(second.findSession('a-token').userId, alice.id);
    // The file holds a hash of the token, never the token itself.
    assert.ok(!fs.readFileSync(file, 'utf8').includes('a-token'));
    assert.ok(!fs.existsSync(`${file}.tmp`));
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
