import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/calendar_date.dart';
import 'core/clock.dart';
import 'features/appointments/appointment_edit_screen.dart';
import 'features/appointments/appointments_repository.dart';
import 'features/appointments/appointments_view_model.dart';
import 'features/appointments/calendar_screen.dart';
import 'features/contacts/contact_edit_screen.dart';
import 'features/contacts/contacts_repository.dart';
import 'features/contacts/contacts_screen.dart';
import 'features/contacts/contacts_view_model.dart';
import 'features/contacts/photos.dart';
import 'features/notes/note_edit_screen.dart';
import 'features/notes/notes_list_screen.dart';
import 'features/notes/notes_repository.dart';
import 'features/notes/notes_view_model.dart';
import 'features/tasks/tasks_repository.dart';
import 'features/tasks/tasks_screen.dart';
import 'features/tasks/tasks_view_model.dart';

// #docregion dependencies
/// Everything the app needs from the outside world, in one place. `main`
/// builds the real ones; tests build fakes.
class AppDependencies {
  const AppDependencies({
    required this.clock,
    required this.notes,
    required this.tasks,
    required this.appointments,
    required this.contacts,
    required this.photoPicker,
    required this.photoStorage,
  });

  final Clock clock;
  final NotesRepository notes;
  final TasksRepository tasks;
  final AppointmentsRepository appointments;
  final ContactsRepository contacts;
  final PhotoPicker photoPicker;
  final PhotoStorage photoStorage;
}
// #enddocregion dependencies

// #docregion router
final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

GoRouter buildRouter({String initialLocation = '/'}) => GoRouter(
  navigatorKey: _rootKey,
  initialLocation: initialLocation,
  routes: [
    // The four tabs. Each branch keeps its own navigation stack and state, so
    // switching tabs does not lose your place.
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => HomeShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const NotesListScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/tasks',
              builder: (context, state) => const TasksScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/calendar',
              builder: (context, state) => const CalendarScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/contacts',
              builder: (context, state) => const ContactsScreen(),
            ),
          ],
        ),
      ],
    ),
    // Editors open above the tab bar, on the root navigator. In each pair,
    // "new" comes before ":id", or "new" would match as an id.
    GoRoute(
      path: '/notes/new',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => const NoteEditScreen(),
    ),
    GoRoute(
      path: '/notes/:id',
      parentNavigatorKey: _rootKey,
      builder: (context, state) =>
          NoteEditScreen(noteId: int.tryParse(state.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/calendar/new',
      parentNavigatorKey: _rootKey,
      builder: (context, state) {
        final day = state.uri.queryParameters['day'];
        return AppointmentEditScreen(
          initialDay: day == null ? null : _tryParseDay(day),
        );
      },
    ),
    GoRoute(
      path: '/calendar/:id',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => AppointmentEditScreen(
        appointmentId: int.tryParse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/contacts/new',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => const ContactEditScreen(),
    ),
    GoRoute(
      path: '/contacts/:id',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => ContactEditScreen(
        contactId: int.tryParse(state.pathParameters['id']!),
      ),
    ),
  ],
);

/// A bad "day" in a link must not crash the screen: ignore it.
CalendarDate? _tryParseDay(String text) {
  try {
    return CalendarDate.parse(text);
  } on FormatException {
    return null;
  }
}
// #enddocregion router

// #docregion shell
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            // Tapping the current tab again returns to its first screen.
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.notes), label: 'Notes'),
          NavigationDestination(icon: Icon(Icons.checklist), label: 'Tasks'),
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          NavigationDestination(icon: Icon(Icons.people), label: 'Contacts'),
        ],
      ),
    );
  }
}
// #enddocregion shell

// #docregion app
/// The composition root: every dependency arrives through the constructor, so
/// a test can start the whole app with fakes.
class OrganizerApp extends StatefulWidget {
  const OrganizerApp({
    super.key,
    required this.dependencies,
    this.initialLocation = '/',
  });

  final AppDependencies dependencies;

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
    final d = widget.dependencies;
    return MultiProvider(
      providers: [
        Provider<Clock>.value(value: d.clock),
        ChangeNotifierProvider(
          create: (_) => NotesViewModel(d.notes, d.clock)..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => TasksViewModel(d.tasks, d.clock)..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => AppointmentsViewModel(d.appointments, d.clock)..load(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              ContactsViewModel(d.contacts, d.photoPicker, d.photoStorage)
                ..load(),
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
