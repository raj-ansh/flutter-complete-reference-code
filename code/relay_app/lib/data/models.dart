import 'package:flutter/foundation.dart';

// Every model is built with a strict `fromJson`: a field that is missing or of
// the wrong type is a FormatException at the boundary, not a mystery later.

// #docregion models
@immutable
class User {
  const User({required this.id, required this.username});
  final String id;
  final String username;

  factory User.fromJson(Object? json) => switch (json) {
    {'id': String id, 'username': String username} => User(
      id: id,
      username: username,
    ),
    _ => throw FormatException('Not a user: $json'),
  };
}

@immutable
class RoomSummary {
  const RoomSummary({
    required this.id,
    required this.name,
    required this.isPublic,
    required this.ownerId,
    required this.memberCount,
    required this.joined,
    required this.invited,
  });

  final String id;
  final String name;
  final bool isPublic;
  final String ownerId;
  final int memberCount;

  /// The signed-in user is a member.
  final bool joined;

  /// The signed-in user has been invited and has not joined yet.
  final bool invited;

  factory RoomSummary.fromJson(Object? json) => switch (json) {
    {
      'id': String id,
      'name': String name,
      'isPublic': bool isPublic,
      'ownerId': String ownerId,
      'memberCount': int memberCount,
      'joined': bool joined,
      'invited': bool invited,
    } =>
      RoomSummary(
        id: id,
        name: name,
        isPublic: isPublic,
        ownerId: ownerId,
        memberCount: memberCount,
        joined: joined,
        invited: invited,
      ),
    _ => throw FormatException('Not a room: $json'),
  };
}

@immutable
class ChatMessage {
  const ChatMessage({
    required this.roomId,
    required this.seq,
    required this.userId,
    required this.username,
    required this.text,
    required this.at,
  });

  final String roomId;

  /// Position in the room, assigned by the server: 1, 2, 3 ...
  final int seq;
  final String userId;
  final String username;
  final String text;
  final DateTime at;

  factory ChatMessage.fromJson(Object? json) => switch (json) {
    {
      'roomId': String roomId,
      'seq': int seq,
      'userId': String userId,
      'username': String username,
      'text': String text,
      'at': int at,
    } =>
      ChatMessage(
        roomId: roomId,
        seq: seq,
        userId: userId,
        username: username,
        text: text,
        at: DateTime.fromMillisecondsSinceEpoch(at, isUtc: true),
      ),
    _ => throw FormatException('Not a message: $json'),
  };
}

@immutable
class Member {
  const Member({
    required this.id,
    required this.username,
    required this.isOwner,
    required this.online,
  });

  final String id;
  final String username;
  final bool isOwner;
  final bool online;

  factory Member.fromJson(Object? json) => switch (json) {
    {
      'id': String id,
      'username': String username,
      'isOwner': bool isOwner,
      'online': bool online,
    } =>
      Member(id: id, username: username, isOwner: isOwner, online: online),
    _ => throw FormatException('Not a member: $json'),
  };
}

@immutable
class Invite {
  const Invite({required this.room, required this.from});
  final RoomSummary room;
  final String from;

  factory Invite.fromJson(Object? json) => switch (json) {
    {'room': final Object? room, 'from': String from} => Invite(
      room: RoomSummary.fromJson(room),
      from: from,
    ),
    _ => throw FormatException('Not an invitation: $json'),
  };
}

/// What a successful sign-in or sign-up returns.
@immutable
class Session {
  const Session({required this.user, required this.token});
  final User user;
  final String token;

  factory Session.fromJson(Object? json) => switch (json) {
    {'user': final Object? user, 'token': String token} => Session(
      user: User.fromJson(user),
      token: token,
    ),
    _ => throw FormatException('Not a session: $json'),
  };
}
// #enddocregion models
