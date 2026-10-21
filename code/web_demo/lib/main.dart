import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() => runApp(const PlatformFactsApp());

// #docregion facts
/// What the running program can learn about where it is running. Everything
/// here works on every platform, including the web: none of it imports dart:io.
Map<String, String> platformFacts() => {
  'Running in a browser (kIsWeb)': '$kIsWeb',
  'Target platform': defaultTargetPlatform.name,
  'Release build (kReleaseMode)': '$kReleaseMode',
  'Compiled to WebAssembly': '${const bool.fromEnvironment('dart.tool.dart2wasm')}',
  'Address of the page (Uri.base)': '${Uri.base}',
};
// #enddocregion facts

class PlatformFactsApp extends StatelessWidget {
  const PlatformFactsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final facts = platformFacts();
    return MaterialApp(
      title: 'Platform facts',
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: Scaffold(
        appBar: AppBar(title: const Text('Platform facts')),
        body: ListView(
          children: [
            for (final entry in facts.entries)
              ListTile(title: Text(entry.key), subtitle: Text(entry.value)),
          ],
        ),
      ),
    );
  }
}
