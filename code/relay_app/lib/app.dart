import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'data/session_store.dart';
import 'data/transport.dart';
import 'state/lobby_view_model.dart';
import 'state/session_view_model.dart';
import 'ui/lobby_screen.dart';
import 'ui/room_screen.dart';
import 'ui/sign_in_screen.dart';

// #docregion dependencies
/// Everything from the outside world, supplied by `main` or by a test.
class RelayDependencies {
  const RelayDependencies({
    required this.store,
    required this.client,
    required this.transport,
  });

  final SessionStore store;
  final http.Client client;
  final RelayTransport transport;
}
// #enddocregion dependencies

// #docregion router
/// The router follows the session: signed out means the sign-in screen, signed
/// in means the rooms. No screen decides this for itself.
GoRouter buildRouter(SessionViewModel session) => GoRouter(
  initialLocation: '/',
  refreshListenable: session, // re-run `redirect` whenever the session changes
  redirect: (context, state) {
    final here = state.matchedLocation;
    return switch (session.state) {
      Restoring() => here == '/splash' ? null : '/splash',
      SignedOut() => here == '/signin' ? null : '/signin',
      SignedIn() => (here == '/signin' || here == '/splash') ? '/' : null,
    };
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
    ),
    GoRoute(path: '/signin', builder: (context, state) => const SignInScreen()),
    // Everything that needs a signed-in user shares one LobbyViewModel.
    ShellRoute(
      builder: (context, state, child) => _SignedInScope(child: child),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const LobbyScreen()),
        GoRoute(
          path: '/room/:id',
          builder: (context, state) =>
              RoomScreen(roomId: state.pathParameters['id']!),
        ),
      ],
    ),
  ],
);

class _SignedInScope extends StatelessWidget {
  const _SignedInScope({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionViewModel>();
    return ChangeNotifierProvider(
      // Created when the user signs in, disposed when they leave this subtree.
      create: (_) =>
          LobbyViewModel(session.service, session.transport.events)..load(),
      child: child,
    );
  }
}
// #enddocregion router

// #docregion app
class RelayApp extends StatefulWidget {
  const RelayApp({super.key, required this.dependencies});
  final RelayDependencies dependencies;

  @override
  State<RelayApp> createState() => _RelayAppState();
}

class _RelayAppState extends State<RelayApp> {
  late final SessionViewModel _session = SessionViewModel(
    store: widget.dependencies.store,
    client: widget.dependencies.client,
    transport: widget.dependencies.transport,
  )..restore();
  late final GoRouter _router = buildRouter(_session);

  @override
  void dispose() {
    _router.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _session,
      child: MaterialApp.router(
        title: 'Relay',
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
        theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.indigo)),
        darkTheme: ThemeData(
          colorScheme: .fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark),
        ),
      ),
    );
  }
}
// #enddocregion app
