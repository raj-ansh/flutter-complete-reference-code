import 'package:flutter/material.dart';

class Note {
  const Note(this.id, this.title);
  final int id;
  final String title;
}

const sampleNotes = [
  Note(1, 'Water tomatoes'),
  Note(2, 'Prune roses'),
  Note(3, 'Buy compost'),
];

// #docregion push
/// A list screen that opens a detail screen and waits for its result.
class NoteListPage extends StatefulWidget {
  const NoteListPage({super.key});

  @override
  State<NoteListPage> createState() => _NoteListPageState();
}

class _NoteListPageState extends State<NoteListPage> {
  final List<Note> _notes = List.of(sampleNotes);

  Future<void> _open(int index) async {
    final note = _notes[index];
    // push returns a Future that completes when the pushed route is popped.
    final newTitle = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => NoteDetailPage(note: note)),
    );
    if (!mounted || newTitle == null) return; // user went back without saving
    setState(() => _notes[index] = Note(note.id, newTitle));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: ListView.builder(
        itemCount: _notes.length,
        itemBuilder: (context, i) =>
            ListTile(title: Text(_notes[i].title), onTap: () => _open(i)),
      ),
    );
  }
}

/// The detail screen receives its data through the constructor and returns a
/// result with Navigator.pop.
class NoteDetailPage extends StatelessWidget {
  const NoteDetailPage({super.key, required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Note ${note.id}'),
      ), // back button is automatic
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(note.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop('${note.title} (done)'),
              child: const Text('Mark done'),
            ),
          ],
        ),
      ),
    );
  }
}
// #enddocregion push

// #docregion stack
/// Moving through a stack of routes.
class StackOps extends StatelessWidget {
  const StackOps({super.key, required this.depth});

  final int depth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Level $depth')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => StackOps(depth: depth + 1),
                ),
              ),
              child: const Text('Push deeper'),
            ),
            OutlinedButton(
              // Replace this screen instead of stacking on top of it.
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => StackOps(depth: depth + 1),
                ),
              ),
              child: const Text('Replace this screen'),
            ),
            TextButton(
              // Pop everything down to the first route.
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('Back to start'),
            ),
          ],
        ),
      ),
    );
  }
}
// #enddocregion stack

// #docregion named
/// Named routes: still supported, and common in older code. The Flutter
/// documentation does not recommend them for most apps (see the chapter).
class NamedRoutesApp extends StatelessWidget {
  const NamedRoutesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/',
      routes: {
        '/': (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () =>
                  Navigator.pushNamed(context, '/detail', arguments: 42),
              child: const Text('Open detail'),
            ),
          ),
        ),
        '/detail': (context) {
          final id = ModalRoute.of(context)!.settings.arguments as int;
          return Scaffold(body: Center(child: Text('Detail for $id')));
        },
      },
    );
  }
}
// #enddocregion named
