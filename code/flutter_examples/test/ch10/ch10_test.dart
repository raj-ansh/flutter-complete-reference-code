import 'package:flutter/material.dart';
import 'package:flutter_examples/ch10/catalogs.dart';
import 'package:flutter_examples/ch10/cupertino_demo.dart';
import 'package:flutter_examples/ch10/theming.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/capture.dart';
import '../support/screenshot.dart';

String hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

Widget themed(Widget home, ThemeData theme) =>
    MaterialApp(debugShowCheckedModeBanner: false, theme: theme, home: home);

void main() {
  testWidgets('sample page in light and dark', (tester) async {
    await saveScreenshot(
      tester,
      const ThemedApp(themeMode: ThemeMode.light),
      'ch10_sample_light',
      size: const Size(360, 600),
    );
    await saveScreenshot(
      tester,
      const ThemedApp(themeMode: ThemeMode.dark),
      'ch10_sample_dark',
      size: const Size(360, 600),
    );
  });

  testWidgets('color roles and type scale', (tester) async {
    await saveScreenshot(
      tester,
      themed(
        const Scaffold(body: SingleChildScrollView(child: ColorRoles())),
        buildTheme(Brightness.light),
      ),
      'ch10_color_roles_light',
      size: const Size(360, 460),
    );
    await saveScreenshot(
      tester,
      themed(
        const Scaffold(body: SingleChildScrollView(child: ColorRoles())),
        buildTheme(Brightness.dark),
      ),
      'ch10_color_roles_dark',
      size: const Size(360, 460),
    );
    await saveScreenshot(
      tester,
      themed(const Scaffold(body: TypeScale()), buildTheme(Brightness.light)),
      'ch10_type_scale',
      size: const Size(360, 420),
    );

    // Record the real numbers behind the pictures.
    final light = buildTheme(Brightness.light);
    final dark = buildTheme(Brightness.dark);
    final s = light.colorScheme;
    final d = dark.colorScheme;
    final colorLines = StringBuffer()
      ..writeln('role                      light      dark')
      ..writeln(
        'primary                   ${hex(s.primary)}    ${hex(d.primary)}',
      )
      ..writeln(
        'onPrimary                 ${hex(s.onPrimary)}    ${hex(d.onPrimary)}',
      )
      ..writeln(
        'primaryContainer          ${hex(s.primaryContainer)}    ${hex(d.primaryContainer)}',
      )
      ..writeln(
        'secondary                 ${hex(s.secondary)}    ${hex(d.secondary)}',
      )
      ..writeln(
        'tertiary                  ${hex(s.tertiary)}    ${hex(d.tertiary)}',
      )
      ..writeln('error                     ${hex(s.error)}    ${hex(d.error)}')
      ..writeln(
        'surface                   ${hex(s.surface)}    ${hex(d.surface)}',
      )
      ..writeln(
        'onSurface                 ${hex(s.onSurface)}    ${hex(d.onSurface)}',
      );
    writeCaptured('ch10_color_roles.txt', colorLines.toString());

    // A bare ThemeData has no font sizes yet; they are filled in when the theme
    // is used inside an app, so read the theme as a widget sees it.
    late TextTheme t;
    await tester.pumpWidget(
      themed(
        Builder(
          builder: (context) {
            t = Theme.of(context).textTheme;
            return const SizedBox();
          },
        ),
        light,
      ),
    );
    final styles = <String, TextStyle?>{
      'displayLarge': t.displayLarge,
      'displayMedium': t.displayMedium,
      'displaySmall': t.displaySmall,
      'headlineLarge': t.headlineLarge,
      'headlineMedium': t.headlineMedium,
      'headlineSmall': t.headlineSmall,
      'titleLarge': t.titleLarge,
      'titleMedium': t.titleMedium,
      'titleSmall': t.titleSmall,
      'bodyLarge': t.bodyLarge,
      'bodyMedium': t.bodyMedium,
      'bodySmall': t.bodySmall,
      'labelLarge': t.labelLarge,
      'labelMedium': t.labelMedium,
      'labelSmall': t.labelSmall,
    };
    final sizes = StringBuffer()..writeln('style              size  weight');
    styles.forEach((name, style) {
      final weight = style?.fontWeight?.value ?? 400;
      sizes.writeln(
        '${name.padRight(18)} ${style?.fontSize?.toStringAsFixed(0).padLeft(3)}   w$weight',
      );
    });
    writeCaptured('ch10_text_theme.txt', sizes.toString());
    expect(light.useMaterial3, isTrue);
  });

  testWidgets('buttons, segmented button and components', (tester) async {
    await saveScreenshot(
      tester,
      themed(
        const Scaffold(body: SingleChildScrollView(child: ButtonCatalog())),
        buildTheme(Brightness.light),
      ),
      'ch10_buttons',
      size: const Size(360, 560),
    );
    await saveScreenshot(
      tester,
      themed(
        const Scaffold(body: SegmentedDemo()),
        buildTheme(Brightness.light),
      ),
      'ch10_segmented',
      size: const Size(360, 120),
    );
    await saveScreenshot(
      tester,
      themed(const ComponentCatalog(), buildTheme(Brightness.light)),
      'ch10_components',
      size: const Size(360, 640),
    );
  });

  testWidgets('theme extension and component themes', (tester) async {
    await saveScreenshot(
      tester,
      themed(
        const Scaffold(
          body: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusBadge(ok: true),
                SizedBox(width: 8),
                StatusBadge(ok: false),
              ],
            ),
          ),
        ),
        themeWithStatusColors(),
      ),
      'ch10_extension',
      size: const Size(360, 100),
    );
    await saveScreenshot(
      tester,
      themed(
        Scaffold(
          body: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton(
                onPressed: () {},
                child: const Text('Squarer, roomier'),
              ),
              const Card(
                child: ListTile(title: Text('Card with 12 px margin')),
              ),
            ],
          ),
        ),
        themeWithRoundedButtons(),
      ),
      'ch10_component_theme',
      size: const Size(360, 200),
    );
  });

  testWidgets('cupertino and adaptive widgets', (tester) async {
    await saveScreenshot(
      tester,
      const CupertinoSettings(),
      'ch10_cupertino',
      size: const Size(360, 480),
    );
    await saveScreenshot(
      tester,
      const AdaptiveSwitchDemo(platform: TargetPlatform.android),
      'ch10_adaptive_android',
      size: const Size(180, 90),
    );
    await saveScreenshot(
      tester,
      const AdaptiveSwitchDemo(platform: TargetPlatform.iOS),
      'ch10_adaptive_ios',
      size: const Size(180, 90),
    );
  });
}
