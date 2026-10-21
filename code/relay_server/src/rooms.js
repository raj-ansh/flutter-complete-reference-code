'use strict';
// The rules of the chat: who may do what. Nothing here knows about sockets, so
// every rule can be tested by plain function calls.

const validate = require('./validation');
const { ok, fail } = require('./results');

const KEEP_MESSAGES = 500; // history kept per room

class Rooms {
  /** @param {import('./store').Store} store @param {{ now?: () => number }} options */
  constructor(store, options = {}) {
    this.store = store;
    this.now = options.now ?? Date.now;
  }

  // ---- looking up --------------------------------------------------------
  /**
   * A room the user is allowed to know about, or a not_found failure. A private
   * room the user has no link to looks exactly like a room that does not exist,
   * so its existence is not revealed.
   */
  _visible(userId, roomId) {
    const id = validate.id(roomId);
    if (!id.ok) return fail('not_found', 'No such room.');
    const room = this.store.rooms.get(id.value);
    if (!room || room.closed) return fail('not_found', 'No such room.');
    const linked = room.members.has(userId) || room.invited.has(userId);
    if (!room.isPublic && !linked) return fail('not_found', 'No such room.');
    return ok({ room });
  }

  _asMember(userId, roomId) {
    const found = this._visible(userId, roomId);
    if (!found.ok) return found;
    if (!found.room.members.has(userId)) return fail('forbidden', 'You are not in this room.');
    return found;
  }

  _asOwner(userId, roomId) {
    const found = this._asMember(userId, roomId);
    if (!found.ok) return found;
    if (found.room.ownerId !== userId) return fail('forbidden', 'Only the room owner can do that.');
    return found;
  }

  _userNamed(name) {
    const parsed = validate.username(name);
    const user = parsed.ok ? this.store.findUserByName(parsed.value) : null;
    return user ? ok({ user }) : fail('not_found', 'No such user.');
  }

  _summary(room, userId) {
    return {
      id: room.id,
      name: room.name,
      isPublic: room.isPublic,
      ownerId: room.ownerId,
      memberCount: room.members.size,
      joined: room.members.has(userId),
      invited: room.invited.has(userId),
    };
  }

  // ---- actions -----------------------------------------------------------
  create(userId, options) {
    const { name, isPublic } = options !== null && typeof options === 'object' ? options : {};
    const roomName = validate.roomName(name);
    if (!roomName.ok) return fail('invalid', roomName.message);
    if (typeof isPublic !== 'boolean') return fail('invalid', 'isPublic must be true or false');
    const room = this.store.addRoom({ name: roomName.value, ownerId: userId, isPublic });
    return ok({ room: this._summary(room, userId) });
  }

  /** Rooms the user is in, has been invited to, or that are public. */
  list(userId) {
    const rooms = [...this.store.rooms.values()]
      .filter((r) => !r.closed && (r.isPublic || r.members.has(userId) || r.invited.has(userId)))
      .map((r) => this._summary(r, userId));
    return ok({ rooms });
  }

  join(userId, roomId) {
    const found = this._visible(userId, roomId);
    if (!found.ok) return found;
    const { room } = found;
    if (room.members.has(userId)) return ok({ room: this._summary(room, userId) }); // already in
    if (!room.isPublic && !room.invited.has(userId)) return fail('forbidden', 'This room is by invitation only.');
    room.members.add(userId);
    room.invited.delete(userId);
    this.store.changed();
    return ok({ room: this._summary(room, userId) });
  }

  leave(userId, roomId) {
    const found = this._asMember(userId, roomId);
    if (!found.ok) return found;
    if (found.room.ownerId === userId) {
      return fail('forbidden', 'The owner cannot leave. Close the room instead.');
    }
    found.room.members.delete(userId);
    this.store.changed();
    return ok();
  }

  invite(userId, roomId, targetName) {
    const found = this._asMember(userId, roomId);
    if (!found.ok) return found;
    const target = this._userNamed(targetName);
    if (!target.ok) return target;
    const { room } = found;
    if (room.members.has(target.user.id)) return fail('conflict', 'That user is already in the room.');
    room.invited.add(target.user.id);
    this.store.changed();
    return ok({ targetId: target.user.id, room: this._summary(room, target.user.id) });
  }

  kick(userId, roomId, targetName) {
    const found = this._asOwner(userId, roomId);
    if (!found.ok) return found;
    const target = this._userNamed(targetName);
    if (!target.ok) return target;
    const { room } = found;
    if (target.user.id === userId) return fail('invalid', 'You cannot remove yourself; close the room instead.');
    if (!room.members.has(target.user.id)) return fail('not_found', 'That user is not in the room.');
    room.members.delete(target.user.id);
    room.invited.delete(target.user.id);
    this.store.changed();
    return ok({ targetId: target.user.id });
  }

  close(userId, roomId) {
    const found = this._asOwner(userId, roomId);
    if (!found.ok) return found;
    const memberIds = [...found.room.members];
    found.room.closed = true;
    this.store.changed();
    return ok({ memberIds });
  }

  // #docregion send
  send(userId, roomId, text) {
    const found = this._asMember(userId, roomId);
    if (!found.ok) return found;
    const body = validate.messageText(text);
    if (!body.ok) return fail('invalid', body.message);
    const { room } = found;
    // The server decides everything about the message except its words: the
    // sequence number, the sender and the time. A client cannot forge any.
    const message = { seq: room.nextSeq++, userId, text: body.value, at: this.now() };
    room.messages.push(message);
    if (room.messages.length > KEEP_MESSAGES) room.messages.splice(0, room.messages.length - KEEP_MESSAGES);
    this.store.changed();
    return ok({ message: this._publicMessage(room, message) });
  }
  // #enddocregion send

  /**
   * Without afterSeq: the latest [limit] messages. With afterSeq: the messages
   * after that number, oldest first, up to [limit] (for catching up).
   */
  history(userId, roomId, options) {
    const found = this._asMember(userId, roomId);
    if (!found.ok) return found;
    // A default parameter would not cover null, a string or an array: take the
    // two fields only from a plain object.
    const { afterSeq, limit } = options !== null && typeof options === 'object' ? options : {};
    const max = validate.integerInRange(limit, 1, validate.LIMITS.historyMax, 50);
    if (!max.ok) return fail('invalid', `limit ${max.message}`);
    const after = validate.integerInRange(afterSeq, 0, Number.MAX_SAFE_INTEGER, null);
    if (!after.ok) return fail('invalid', `afterSeq ${after.message}`);
    const { room } = found;
    const messages =
      after.value === null
        ? room.messages.slice(-max.value)
        : room.messages.filter((m) => m.seq > after.value).slice(0, max.value);
    return ok({ messages: messages.map((m) => this._publicMessage(room, m)) });
  }

  members(userId, roomId) {
    const found = this._asMember(userId, roomId);
    if (!found.ok) return found;
    const { room } = found;
    const members = [...room.members].map((id) => ({
      id,
      username: this.store.users.get(id)?.username ?? 'unknown',
      isOwner: id === room.ownerId,
    }));
    return ok({ members });
  }

  _publicMessage(room, m) {
    return {
      roomId: room.id,
      seq: m.seq,
      userId: m.userId,
      username: this.store.users.get(m.userId)?.username ?? 'unknown',
      text: m.text,
      at: m.at,
    };
  }

  /** Ids of the rooms a user belongs to (for joining their socket channels). */
  roomIdsOf(userId) {
    return [...this.store.rooms.values()].filter((r) => !r.closed && r.members.has(userId)).map((r) => r.id);
  }
}

module.exports = { Rooms, KEEP_MESSAGES };
