import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_examples/ch16/assets_demo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../support/capture.dart';
import '../support/screenshot.dart';

Widget app(Widget body) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.teal)),
  home: Scaffold(body: SizedBox.expand(child: body)),
);

/// Lets real I/O (sockets, image decoding) progress, then rebuilds, until
/// [done] is true or about five seconds have passed.
Future<void> waitFor(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 50 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
}

void main() {
  testWidgets('resolution-aware assets: which file is chosen', (tester) async {
    const provider = AssetImage('assets/images/leaf.png');
    final rows = StringBuffer()
      ..writeln('device pixel ratio   file chosen                      scale');
    for (final ratio in [1.0, 1.5, 1.8, 2.0, 2.7, 3.0, 4.0]) {
      final key = await tester.runAsync(
        () => provider.obtainKey(
          ImageConfiguration(devicePixelRatio: ratio, bundle: rootBundle),
        ),
      );
      rows.writeln(
        '${ratio.toString().padRight(21)}${key!.name.padRight(32)}${key.scale}',
      );
    }
    writeCaptured('ch16_resolution.txt', rows.toString());
    final k1 = await tester.runAsync(
      () => provider.obtainKey(const ImageConfiguration(devicePixelRatio: 1.0)),
    );
    final k27 = await tester.runAsync(
      () => provider.obtainKey(const ImageConfiguration(devicePixelRatio: 2.7)),
    );
    expect(k1!.name, 'assets/images/leaf.png');
    expect(k27!.name, 'assets/images/3.0x/leaf.png');
  });

  testWidgets('JSON asset loads through the bundle', (tester) async {
    final plants = await tester.runAsync(() => loadPlants(rootBundle));
    expect(plants!.map((p) => p.name), ['Basil', 'Fern', 'Tomato']);
    expect(plants[2].heightCm, 150);

    await saveScreenshot(
      tester,
      app(const PlantList()),
      'ch16_plant_list',
      size: const Size(360, 260),
      settle: false,
      beforeCapture: (t) async {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await t.pump();
      },
    );
  });

  testWidgets('a failing load shows the error state', (tester) async {
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _EmptyBundle(),
        child: MaterialApp(home: Scaffold(body: const PlantList())),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Could not load'), findsOneWidget);
  });

  testWidgets('custom font, icons, BoxFit and SVG', (tester) async {
    await saveScreenshot(
      tester,
      app(const FontDemo()),
      'ch16_fonts',
      size: const Size(360, 320),
    );
    await saveScreenshot(
      tester,
      app(const IconDemo()),
      'ch16_icons',
      size: const Size(360, 140),
    );
    await saveScreenshot(
      tester,
      app(const Padding(padding: EdgeInsets.all(12), child: FitDemo())),
      'ch16_boxfit',
      size: const Size(360, 240),
      settle: false,
      beforeCapture: (t) async {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await t.pump();
      },
    );
    await saveScreenshot(
      tester,
      app(const SvgDemo()),
      'ch16_svg',
      size: const Size(360, 200),
      settle: false,
      beforeCapture: (t) async {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await t.pump();
      },
    );
    expect(find.byType(SvgPicture), findsNWidgets(3));
  });

  testWidgets('decoded size: a 2000 x 2000 image and cacheWidth', (
    tester,
  ) async {
    final cache = PaintingBinding.instance.imageCache..clear();
    await tester.pumpWidget(app(const SizedBox()));
    final context = tester.element(find.byType(SizedBox).first);

    Future<int> decodedBytes(ImageProvider provider) async {
      cache.clear();
      await tester.runAsync(() => precacheImage(provider, context));
      return cache.currentSizeBytes;
    }

    const full = AssetImage('assets/images/big_gradient.png');
    final fullBytes = await decodedBytes(full);
    final smallBytes = await decodedBytes(ResizeImage(full, width: 200));
    final file = File('assets/images/big_gradient.png').lengthSync();

    writeCaptured(
      'ch16_decoded_size.txt',
      'big_gradient.png: 2000 x 2000 pixels, $file bytes on disk\n'
          'decoded at full size:      $fullBytes bytes in the image cache\n'
          'decoded with width: 200:   $smallBytes bytes in the image cache',
    );
    expect(fullBytes, 2000 * 2000 * 4);
    expect(smallBytes, 200 * 200 * 4);
    cache.clear();
  });

  testWidgets('network image: success and failure', (tester) async {
    final png = File('assets/images/2.0x/leaf.png').readAsBytesSync();
    late HttpServer server;
    final oldOverrides = HttpOverrides.current;
    await tester.runAsync(() async {
      HttpOverrides.global = null; // allow real sockets to localhost
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) {
        if (request.uri.path == '/leaf.png') {
          request.response.headers.contentType = ContentType('image', 'png');
          request.response.add(png);
        } else {
          request.response.statusCode = 404;
        }
        request.response.close();
      });
    });
    addTearDown(() async {
      await tester.runAsync(() => server.close(force: true));
      HttpOverrides.global = oldOverrides;
    });

    final base = 'http://127.0.0.1:${server.port}';
    await tester.pumpWidget(
      app(Center(child: NetworkPhoto(url: '$base/leaf.png'))),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget); // loading
    await waitFor(
      tester,
      () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.broken_image), findsNothing);

    await tester.pumpWidget(
      app(Center(child: NetworkPhoto(url: '$base/missing.png'))),
    );
    await waitFor(
      tester,
      () => find.byIcon(Icons.broken_image).evaluate().isNotEmpty,
    );
    expect(find.byIcon(Icons.broken_image), findsOneWidget); // 404 -> fallback

    // Remove the images and let any leftover timers run out.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });
}

class _EmptyBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) =>
      Future<ByteData>.error(FlutterError('no such asset: $key'));
}
