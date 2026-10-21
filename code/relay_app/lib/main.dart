import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app.dart';
import 'data/session_store.dart';
import 'data/transport.dart';

void main() {
  runApp(
    RelayApp(
      dependencies: RelayDependencies(
        store: SessionStore(),
        client: http.Client(),
        transport: SocketIoTransport(),
      ),
    ),
  );
}
