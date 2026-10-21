import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the fonts that ship with the Flutter SDK so that screenshots taken
/// in widget tests show real text and icons instead of placeholder boxes.
Future<void> loadSdkFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) {
    throw StateError('FLUTTER_ROOT is not set; run through `flutter test`.');
  }
  final dir = '$root/bin/cache/artifacts/material_fonts';

  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = await File('$dir/$file').readAsBytes();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('Roboto', [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-italic.ttf',
    'roboto-light.ttf',
  ]);
  // Cupertino widgets ask for Apple's system fonts, which this machine does
  // not have. Draw their text with Roboto so screenshots show real letters.
  for (final alias in ['CupertinoSystemText', 'CupertinoSystemDisplay']) {
    await load(alias, [
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf',
    ]);
  }
  await load('MaterialIcons', ['materialicons-regular.otf']);

}

/// Directory that receives the PNG files used in the book.
String get shotDirectory =>
    Platform.environment['SHOT_DIR'] ??
    '${Directory.current.path}/../../diagrams/shots';

/// Renders [app] at [size] logical pixels and saves it as `$name.png`.
Future<void> saveScreenshot(
  WidgetTester tester,
  Widget app,
  String name, {
  Size size = const Size(360, 640),
  double pixelRatio = 2,
  Future<void> Function(WidgetTester tester)? beforeCapture,
  bool settle = true,
}) async {
  await tester.runAsync(loadSdkFonts);
  WidgetsApp.debugAllowBannerOverride = false; // no DEBUG ribbon in the book
  // The test binding draws shadows as solid blocks; draw real ones instead.
  debugDisableShadows = false;
  // Touch-style focus, so a simulated tap does not leave a keyboard focus ring.
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
  addTearDown(() {
    WidgetsApp.debugAllowBannerOverride = true;
    debugDisableShadows = true;
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });
  tester.view.physicalSize = size * pixelRatio;
  tester.view.devicePixelRatio = pixelRatio;
  addTearDown(tester.view.reset);

  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(key: key, child: app));
  settle
      ? await tester.pumpAndSettle()
      : await tester.pump(const Duration(milliseconds: 300));
  if (beforeCapture != null) {
    await beforeCapture(tester);
    // With settle: false the callback controls time exactly, so a screenshot
    // can show an animation part-way through.
    settle ? await tester.pumpAndSettle() : await tester.pump();
  }
  FocusManager.instance.primaryFocus?.unfocus();
  settle ? await tester.pumpAndSettle() : await tester.pump();

  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$shotDirectory/$name.png');
    await file.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
  });
  // The test framework verifies this flag is back to its default when the
  // test body ends, which happens before tear-down callbacks run.
  debugDisableShadows = true;
}
