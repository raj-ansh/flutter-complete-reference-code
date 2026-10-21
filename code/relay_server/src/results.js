'use strict';
// Every operation returns a plain result object instead of throwing, so that
// "the user did something not allowed" is an ordinary, testable outcome.
//
//   { ok: true, ...data }
//   { ok: false, code, message }
//
// Codes: invalid (bad input), unauthorized (not signed in or wrong password),
// forbidden (signed in but not allowed), not_found, conflict, rate_limited,
// too_large (request body over the limit).

const ok = (data = {}) => ({ ok: true, ...data });
const fail = (code, message, extra = {}) => ({ ok: false, code, message, ...extra });

module.exports = { ok, fail };
