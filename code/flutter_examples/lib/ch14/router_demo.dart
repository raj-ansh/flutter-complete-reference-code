import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// #docregion router
/// A tiny stand-in for real sign-in state. Changing it re-runs redirects.
final signedIn = ValueNotifier<bool>(false);

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    // Re-evaluate redirects whenever the sign-in state changes.
    refreshListenable: signedIn,
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login';
      final needsAccount = state.matchedLocation.startsWith('/account');

      if (!signedIn.value && needsAccount) {
        // Remember where the user wanted to go.
        final from = Uri.encodeComponent(state.uri.toString());
        return '/login?from=$from';
      }
      if (signedIn.value && loggingIn) {
        return state.uri.queryParameters['from'] ?? '/';
      }
      return null; // no redirect
    },
    errorBuilder: (context, state) =>
        NotFoundScreen(location: state.uri.toString()),
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/notes/:id', // :id is a path parameter
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return NoteScreen(id: id);
        },
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) =>
            SearchScreen(query: state.uri.queryParameters['q'] ?? ''),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/account',
        builder: (context, state) => const AccountScreen(),
      ),
    ],
  );
}
// #enddocregion router

class RouterApp extends StatefulWidget {
  const RouterApp({super.key, required this.router});

  final GoRouter router;

  @override
  State<RouterApp> createState() => _RouterAppState();
}

class _RouterAppState extends State<RouterApp> {
  @override
  void dispose() {
    widget.router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: widget.router,
    );
  }
}

// #docregion screens
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Open note 3 (go)'),
            // go replaces the current location with a new one.
            onTap: () => context.go('/notes/3'),
          ),
          ListTile(
            title: const Text('Open note 7 (push)'),
            // push adds a page on top, so Back returns here.
            onTap: () => context.push('/notes/7'),
          ),
          ListTile(
            title: const Text('Search for "tomato"'),
            onTap: () => context.go('/search?q=tomato'),
          ),
          ListTile(
            title: const Text('My account'),
            onTap: () => context.go('/account'),
          ),
          ListTile(
            title: const Text('A page that does not exist'),
            onTap: () => context.go('/nope'),
          ),
        ],
      ),
    );
  }
}

class NoteScreen extends StatelessWidget {
  const NoteScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Note $id')),
      body: Center(
        child: FilledButton(
          // pop can carry a result back to whoever called push.
          onPressed: () => context.pop('closed note $id'),
          child: const Text('Close'),
        ),
      ),
    );
  }
}

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Center(child: Text('Results for "$query"')),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Center(
        child: FilledButton(
          onPressed: () => signedIn.value = true,
          child: const Text('Sign in'),
        ),
      ),
    );
  }
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: const Center(child: Text('Your account')),
    );
  }
}

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No page at $location'),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Go home'),
            ),
          ],
        ),
      ),
    );
  }
}
// #enddocregion screens
