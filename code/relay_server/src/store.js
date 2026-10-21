'use strict';
// The data, kept in memory, optionally saved to one JSON file. This module only
// stores and finds things; the rules live in auth.js and rooms.js.

const fs = require('node:fs');
const { randomBytes, createHash } = require('node:crypto');

const newId = () => randomBytes(8).toString('hex'); // 16 lower-case hex characters
const sha256 = (text) => createHash('sha256').update(text).digest('hex');

class Store {
  /** @param {{ dataFile?: string }} options */
  constructor(options = {}) {
    this.dataFile = options.dataFile ?? null;
    this.users = new Map(); // id -> { id, username, passwordHash, createdAt }
    this.sessions = new Map(); // sha256(token) -> { userId, expiresAt }
    this.rooms = new Map(); // id -> room
    this._saveTimer = null;
    if (this.dataFile && fs.existsSync(this.dataFile)) this._load();
  }

  // ---- users -------------------------------------------------------------
  findUserByName(name) {
    for (const user of this.users.values()) if (user.username === name) return user;
    return null;
  }

  addUser({ username, passwordHash }) {
    const user = { id: newId(), username, passwordHash, createdAt: Date.now() };
    this.users.set(user.id, user);
    this.changed();
    return user;
  }

  // ---- sessions ----------------------------------------------------------
  // Only a hash of each token is stored. A copy of the data file therefore
  // does not let anyone sign in as a user.
  addSession(token, userId, expiresAt) {
    this.sessions.set(sha256(token), { userId, expiresAt });
    this.changed();
  }

  findSession(token) {
    return this.sessions.get(sha256(token)) ?? null;
  }

  removeSession(token) {
    this.sessions.delete(sha256(token));
    this.changed();
  }

  // ---- rooms -------------------------------------------------------------
  addRoom({ name, ownerId, isPublic }) {
    const room = {
      id: newId(),
      name,
      ownerId,
      isPublic,
      closed: false,
      members: new Set([ownerId]),
      invited: new Set(),
      messages: [], // { seq, id, userId, text, at }
      nextSeq: 1,
      createdAt: Date.now(),
    };
    this.rooms.set(room.id, room);
    this.changed();
    return room;
  }

  // ---- saving ------------------------------------------------------------
  /** Call after any change. Saving is delayed and merged so bursts cost one write. */
  changed() {
    if (!this.dataFile || this._saveTimer) return;
    this._saveTimer = setTimeout(() => {
      this._saveTimer = null;
      this.trySave();
    }, 200);
    this._saveTimer.unref();
  }

  /**
   * Saves, but a failure (disk full, folder gone) is reported instead of thrown.
   * An exception inside a timer would otherwise end the whole server process.
   * @returns {boolean} whether the data was saved
   */
  trySave() {
    try {
      this.saveNow();
      return true;
    } catch (error) {
      console.error(`[relay] could not save the data file: ${error.message}`);
      return false;
    }
  }

  saveNow() {
    if (!this.dataFile) return;
    const snapshot = {
      users: [...this.users.values()],
      sessions: [...this.sessions.entries()],
      rooms: [...this.rooms.values()].map((r) => ({
        ...r,
        members: [...r.members],
        invited: [...r.invited],
      })),
    };
    // Write to a temporary file, then rename: a crash cannot leave half a file.
    const temp = `${this.dataFile}.tmp`;
    fs.writeFileSync(temp, JSON.stringify(snapshot));
    fs.renameSync(temp, this.dataFile);
  }

  _load() {
    const snapshot = JSON.parse(fs.readFileSync(this.dataFile, 'utf8'));
    for (const u of snapshot.users) this.users.set(u.id, u);
    for (const [key, s] of snapshot.sessions) this.sessions.set(key, s);
    for (const r of snapshot.rooms) {
      this.rooms.set(r.id, { ...r, members: new Set(r.members), invited: new Set(r.invited) });
    }
  }
}

module.exports = { Store, newId, sha256 };
