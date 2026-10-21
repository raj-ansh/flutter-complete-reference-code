import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/result.dart';
import 'models.dart';

// #docregion api
/// The HTTP half of the server: sign up, sign in, sign out.
class RelayApi {
  RelayApi({
    required this.client,
    required this.baseUri,
    this.timeout = const Duration(seconds: 10),
  });

  final http.Client client;
  final Uri baseUri;
  final Duration timeout;

  Future<Result<Session>> register(String username, String password) =>
      _post('/api/register', {'username': username, 'password': password});

  Future<Result<Session>> login(String username, String password) =>
      _post('/api/login', {'username': username, 'password': password});

  Future<void> logout(String token) async {
    try {
      await client
          .post(
            baseUri.replace(path: '/api/logout'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: '{}',
          )
          .timeout(timeout);
    } on Object {
      // Signing out locally must never fail because the network is down; the
      // token expires on the server by itself.
    }
  }

  Future<Result<Session>> _post(String path, Map<String, String> body) async {
    try {
      final response = await client
          .post(
            baseUri.replace(path: path),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(body),
          )
          .timeout(timeout);
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (json is Map<String, Object?> && json['ok'] == true) {
        return Ok(Session.fromJson(json));
      }
      if (json is Map<String, Object?> &&
          json['code'] is String &&
          json['message'] is String) {
        return Err(json['code']! as String, json['message']! as String);
      }
      return const Err('bad_response', 'The server sent an unexpected answer.');
    } on TimeoutException {
      return const Err('timeout', 'The server took too long to answer.');
    } on SocketException {
      return const Err('network', 'Could not reach the server.');
    } on http.ClientException {
      return const Err('network', 'Could not reach the server.');
    } on FormatException {
      return const Err('bad_response', 'The server sent an unexpected answer.');
    }
  }
}
// #enddocregion api
