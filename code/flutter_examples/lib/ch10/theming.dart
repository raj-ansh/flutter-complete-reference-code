import 'package:flutter/material.dart';

// #docregion themes
/// One seed color produces a complete, harmonious scheme in both brightnesses.
ThemeData buildTheme(Brightness brightness) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF00695C),
      brightness: brightness,
    ),
  );
}

class ThemedApp extends StatelessWidget {
  const ThemedApp({super.key, this.themeMode = ThemeMode.system});

  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Themed',
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeMode,
      home: const SamplePage(),
    );
  }
}
// #enddocregion themes

// #docregion sample
class SamplePage extends StatelessWidget {
  const SamplePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Garden notes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Today', style: text.headlineSmall),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Water the tomatoes', style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Morning is best, before the sun is high.',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: const [
              Chip(label: Text('outdoors')),
              Chip(label: Text('daily')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton(onPressed: () {}, child: const Text('Done')),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () {}, child: const Text('Later')),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Frost expected tonight',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}
// #enddocregion sample

// #docregion roles
/// Draws each color role of the current scheme as a labelled swatch.
class ColorRoles extends StatelessWidget {
  const ColorRoles({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final roles = <(String, Color, Color)>[
      ('primary', s.primary, s.onPrimary),
      ('primaryContainer', s.primaryContainer, s.onPrimaryContainer),
      ('secondary', s.secondary, s.onSecondary),
      ('secondaryContainer', s.secondaryContainer, s.onSecondaryContainer),
      ('tertiary', s.tertiary, s.onTertiary),
      ('tertiaryContainer', s.tertiaryContainer, s.onTertiaryContainer),
      ('error', s.error, s.onError),
      ('surface', s.surface, s.onSurface),
      ('surfaceContainerHighest', s.surfaceContainerHighest, s.onSurface),
      ('inverseSurface', s.inverseSurface, s.onInverseSurface),
    ];
    return Column(
      children: [
        for (final (name, color, onColor) in roles)
          Container(
            height: 44,
            color: color,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            child: Text(name, style: TextStyle(color: onColor)),
          ),
      ],
    );
  }
}
// #enddocregion roles

// #docregion typescale
/// Shows every text style of the current theme.
class TypeScale extends StatelessWidget {
  const TypeScale({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final styles = <(String, TextStyle?)>[
      ('displayMedium', t.displayMedium),
      ('headlineMedium', t.headlineMedium),
      ('titleLarge', t.titleLarge),
      ('titleMedium', t.titleMedium),
      ('bodyLarge', t.bodyLarge),
      ('bodyMedium', t.bodyMedium),
      ('labelLarge', t.labelLarge),
      ('bodySmall', t.bodySmall),
    ];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [for (final (name, style) in styles) Text(name, style: style)],
    );
  }
}
// #enddocregion typescale

// #docregion extension
/// Custom design tokens that the standard ColorScheme does not have.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({required this.success, required this.warning});

  final Color success;
  final Color warning;

  @override
  StatusColors copyWith({Color? success, Color? warning}) {
    return StatusColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
    );
  }

  @override
  StatusColors lerp(ThemeExtension<StatusColors>? other, double t) {
    if (other is! StatusColors) return this;
    return StatusColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

ThemeData themeWithStatusColors() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
    extensions: const [
      StatusColors(success: Color(0xFF2E7D32), warning: Color(0xFFEF6C00)),
    ],
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.ok});

  final bool ok;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<StatusColors>()!;
    return Chip(
      backgroundColor: ok ? colors.success : colors.warning,
      label: Text(
        ok ? 'Online' : 'Degraded',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}
// #enddocregion extension

// #docregion componenttheme
/// Changing one component for the whole app instead of each use.
ThemeData themeWithRoundedButtons() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
  );
  return base.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      ),
    ),
    cardTheme: const CardThemeData(margin: EdgeInsets.all(12)),
  );
}
// #enddocregion componenttheme
