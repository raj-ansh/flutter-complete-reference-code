import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/clock.dart';
import 'features/notes/note_edit_screen.dart';
import 'features/notes/notes_list_screen.dart';
import 'features/notes/notes_repository.dart';
import 'features/notes/notes_view_model.dart';

// #docregion router
GoRouter buildRouter({String initialLocation = '/'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const NotesListScreen(),
      routes: [
        // "new" must be declared before ":id", or "new" would match as an id.
        GoRoute(
          path: 'notes/new',
          builder: (context, state) => const NoteEditScreen(),
        ),
        GoRoute(
          path: 'notes/:id',
          builder: (context, state) =>
              NoteEditScreen(noteId: int.tryParse(state.pathParameters['id']!)),
        ),
      ],
    ),
  ],
);
// #enddocregion router

// #docregion app
/// The composition root: everything the app needs is passed in here, so tests
/// can start the whole app with fakes.
class OrganizerApp extends StatefulWidget {
  const OrganizerApp({
    super.key,
    required this.notes,
    required this.clock,
    this.initialLocation = '/',
  });

  final NotesRepository notes;
  final Clock clock;

  /// Where the app starts. Tests use it to open a screen directly.
  final String initialLocation;

  @override
  State<OrganizerApp> createState() => _OrganizerAppState();
}

class _OrganizerAppState extends State<OrganizerApp> {
  // Created once. A router built inside build() would be replaced on every
  // rebuild and reset the navigation stack.
  late final _router = buildRouter(initialLocation: widget.initialLocation);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Clock>.value(value: widget.clock),
        ChangeNotifierProvider(
          create: (_) => NotesViewModel(widget.notes, widget.clock)..load(),
        ),
      ],
      child: MaterialApp.router(
        title: 'Pocket Organizer',
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
        theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.teal)),
        darkTheme: ThemeData(
          colorScheme: .fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.dark,
          ),
        ),
      ),
    );
  }
}
// #enddocregion app
