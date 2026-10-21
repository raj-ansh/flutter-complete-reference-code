import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';

// #docregion page
class TaskPage extends StatelessWidget {
  const TaskPage({super.key, required this.count, required this.due});
  final int count;
  final DateTime due;

  @override
  Widget build(BuildContext context) {
    // Every user-visible string comes from the generated class.
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        // The column must be as wide as the screen for "start" to mean the
        // screen's left edge in English and its right edge in Arabic.
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.taskCount(count),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(l10n.dueOn(due)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: Text(l10n.addTask),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// #enddocregion page

// #docregion app
class TaskApp extends StatelessWidget {
  const TaskApp({super.key, this.locale, this.count = 3});
  final Locale? locale;
  final int count;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // The two lines that switch localization on.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Null means "follow the device".
      locale: locale,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      home: TaskPage(count: count, due: DateTime(2026, 10, 21)),
    );
  }
}
// #enddocregion app
