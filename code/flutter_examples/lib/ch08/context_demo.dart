import 'package:flutter/material.dart';

// #docregion bug
/// A widget that builds a MaterialApp and then tries to use that app's
/// Navigator with its OWN context, which sits ABOVE the Navigator.
class WrongContext extends StatelessWidget {
  const WrongContext({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () {
              // 'context' belongs to WrongContext, above MaterialApp.
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const Text('next')),
              );
            },
            child: const Text('Go'),
          ),
        ),
      ),
    );
  }
}
// #enddocregion bug

// #docregion fix
/// The fix: use a context that is BELOW the Navigator. A Builder gives you
/// one without creating a new class.
class RightContext extends StatelessWidget {
  const RightContext({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (innerContext) => TextButton(
              onPressed: () {
                Navigator.of(innerContext).push(
                  MaterialPageRoute<void>(builder: (_) => const Text('next')),
                );
              },
              child: const Text('Go'),
            ),
          ),
        ),
      ),
    );
  }
}
// #enddocregion fix
