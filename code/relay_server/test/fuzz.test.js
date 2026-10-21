'use strict';
// A simple "fuzz" test: throw lots of random, strange values at every input
// check and at the rule functions, and require that nothing ever throws. A
// refusal is fine; an exception from bad input is a bug.
const test = require('node:test');
const assert = require('node:assert/strict');
const v = require('../src/validation');
const { Store } = require('../src/store');
const { Rooms } = require('../src/rooms');
const { capture } = require('./helpers');

// A small seeded generator (so a failure can be reproduced exactly).
function makeRandom(seed) {
  let state = seed >>> 0;
  return () => {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    return state / 2 ** 32;
  };
}

function randomString(next) {
  const alphabets = [
    'abcdefghijklmnopqrstuvwxyz0123456789_',
    ' \t\n\r\u0000\u0007\u001f\u007f',
    'ÄÖÜßéñ日本語🔑🙂‮﻿',
    '%_\\\'";--<>&{}[]$',
  ];
  const length = Math.floor(next() ** 3 * 3000);
  let out = '';
  for (let i = 0; i < length; i++) {
    const alphabet = alphabets[Math.floor(next() * alphabets.length)];
    out += [...alphabet][Math.floor(next() * [...alphabet].length)];
  }
  return out;
}

function randomValue(next) {
  const kind = Math.floor(next() * 12);
  switch (kind) {
    case 0: return undefined;
    case 1: return null;
    case 2: return Math.floor((next() - 0.5) * 1e6);
    case 3: return (next() - 0.5) * 1e300;
    case 4: return [NaN, Infinity, -Infinity, -0][Math.floor(next() * 4)];
    case 5: return next() < 0.5;
    case 6: return [];
    case 7: return { text: randomString(next), roomId: randomString(next) };
    case 8: return Symbol('x') && 'symbol-like';
    case 9: return () => 1;
    case 10: return BigInt(Math.floor(next() * 1e9));
    default: return randomString(next);
  }
}

test('no random input makes a validator throw', () => {
  const next = makeRandom(12345);
  const checks = {
    username: v.username,
    password: v.password,
    roomName: v.roomName,
    messageText: v.messageText,
    id: v.id,
    integerInRange: (x) => v.integerInRange(x, 1, 100, 50),
  };
  let calls = 0;
  let accepted = 0;
  for (let i = 0; i < 20000; i++) {
    const value = randomValue(next);
    for (const [name, check] of Object.entries(checks)) {
      let result;
      assert.doesNotThrow(() => { result = check(value); }, `${name}(${String(value).slice(0, 30)})`);
      assert.equal(typeof result.ok, 'boolean');
      calls++;
      if (result.ok) accepted++;
    }
  }
  capture(
    'relay_fuzz.txt',
    `${calls.toLocaleString('en-US')} validator calls on random strings, numbers, objects and oddities (seed 12345)\n` +
      `exceptions thrown: 0\n` +
      `inputs accepted: ${accepted.toLocaleString('en-US')} (the rest were refused with a message)`,
  );
});

test('no random request makes a room rule throw or break an invariant', () => {
  const next = makeRandom(777);
  const store = new Store();
  const users = ['alice', 'bob', 'carol'].map((n) => store.addUser({ username: n, passwordHash: 'x' }));
  const rooms = new Rooms(store, { now: () => 1 });
  const known = [];
  const actions = ['create', 'list', 'join', 'leave', 'invite', 'kick', 'close', 'send', 'history', 'members'];
  const tally = Object.fromEntries(actions.map((a) => [a, { ok: 0, refused: 0 }]));

  for (let i = 0; i < 30000; i++) {
    const user = users[Math.floor(next() * users.length)];
    const action = actions[Math.floor(next() * actions.length)];
    // Half the time use a real room id, half the time random garbage.
    const roomId = known.length > 0 && next() < 0.5 ? known[Math.floor(next() * known.length)] : randomValue(next);
    const target = next() < 0.5 ? ['alice', 'bob', 'carol'][Math.floor(next() * 3)] : randomValue(next);
    let result;
    assert.doesNotThrow(() => {
      switch (action) {
        case 'create': result = rooms.create(user.id, next() < 0.7 ? { name: `room ${i}`, isPublic: next() < 0.5 } : randomValue(next)); break;
        case 'list': result = rooms.list(user.id); break;
        case 'join': result = rooms.join(user.id, roomId); break;
        case 'leave': result = rooms.leave(user.id, roomId); break;
        case 'invite': result = rooms.invite(user.id, roomId, target); break;
        case 'kick': result = rooms.kick(user.id, roomId, target); break;
        case 'close': result = rooms.close(user.id, roomId); break;
        case 'send': result = rooms.send(user.id, roomId, next() < 0.8 ? `message ${i}` : randomValue(next)); break;
        case 'history': result = rooms.history(user.id, roomId, next() < 0.5 ? randomValue(next) : { limit: 5 }); break;
        default: result = rooms.members(user.id, roomId);
      }
    }, `${action} #${i}`);
    if (action === 'create' && result.ok) known.push(result.room.id);
    tally[action][result.ok ? 'ok' : 'refused']++;
  }

  // Invariants that must hold however the actions were ordered.
  for (const room of store.rooms.values()) {
    assert.ok(room.members.has(room.ownerId), 'the owner is always a member');
    for (const id of room.members) assert.ok(!room.invited.has(id), 'nobody is both member and invited');
    for (let k = 1; k < room.messages.length; k++) {
      assert.ok(room.messages[k].seq > room.messages[k - 1].seq, 'sequence numbers only grow');
    }
    for (const m of room.messages) assert.ok(room.members.size > 0 && typeof m.text === 'string');
  }
  const lines = actions.map((a) => `${a.padEnd(9)} accepted ${String(tally[a].ok).padStart(6)}   refused ${String(tally[a].refused).padStart(6)}`);
  capture(
    'relay_fuzz_rooms.txt',
    `30,000 random actions by 3 users on ${store.rooms.size} rooms (seed 777), half with garbage ids and arguments\n` +
      `exceptions thrown: 0; invariants checked at the end: owner is a member, nobody is member and invited, sequence numbers grow\n${lines.join('\n')}`,
  );
});
