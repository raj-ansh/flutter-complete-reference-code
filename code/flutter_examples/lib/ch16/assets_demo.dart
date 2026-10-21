import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// #docregion model
class PlantInfo {
  const PlantInfo({
    required this.name,
    required this.light,
    required this.heightCm,
  });

  final String name;
  final String light;
  final int heightCm;

  factory PlantInfo.fromJson(Map<String, Object?> json) {
    return PlantInfo(
      name: json['name']! as String,
      light: json['light']! as String,
      heightCm: json['heightCm']! as int,
    );
  }
}

/// Reads and parses a JSON text asset. Taking the bundle as a parameter
/// makes it easy to test with a fake bundle.
Future<List<PlantInfo>> loadPlants(AssetBundle bundle) async {
  final text = await bundle.loadString('assets/data/plants.json');
  final data = jsonDecode(text) as Map<String, Object?>;
  final plants = data['plants']! as List<Object?>;
  return [
    for (final item in plants)
      PlantInfo.fromJson(item! as Map<String, Object?>),
  ];
}
// #enddocregion model

// #docregion loader
class PlantList extends StatelessWidget {
  const PlantList({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the bundle from the context, so a test can supply a different one.
    final bundle = DefaultAssetBundle.of(context);
    return FutureBuilder<List<PlantInfo>>(
      future: loadPlants(bundle),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Could not load: ${snapshot.error}'));
        }
        final plants = snapshot.data;
        if (plants == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          children: [
            for (final p in plants)
              ListTile(
                leading: Image.asset('assets/images/leaf.png', width: 32),
                title: Text(p.name),
                subtitle: Text('${p.light}, ${p.heightCm} cm'),
              ),
          ],
        );
      },
    );
  }
}
// #enddocregion loader

// #docregion fonts
/// The bundled RobotoCondensed family, selected in three ways.
class FontDemo extends StatelessWidget {
  const FontDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Default font (Roboto)', style: TextStyle(fontSize: 22)),
          const Text(
            'RobotoCondensed regular',
            style: TextStyle(fontFamily: 'RobotoCondensed', fontSize: 22),
          ),
          const Text(
            'RobotoCondensed bold (weight 700)',
            style: TextStyle(
              fontFamily: 'RobotoCondensed',
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          // A theme can change the font for a whole subtree.
          Theme(
            data: Theme.of(context).copyWith(
              textTheme: Theme.of(context).textTheme
                  .apply(fontFamily: 'RobotoCondensed'),
            ),
            child: Builder(
              builder: (context) => Text(
                'Themed headline',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// #enddocregion fonts

// #docregion icons
/// Icons are glyphs from a font, so they scale and take any color.
class IconDemo extends StatelessWidget {
  const IconDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          Icon(Icons.eco),
          Icon(Icons.eco, size: 48, color: Colors.green),
          Icon(Icons.eco_outlined, size: 48, color: Colors.green),
          // semanticLabel is read aloud by screen readers.
          Icon(
            Icons.warning,
            size: 48,
            color: Colors.amber,
            semanticLabel: 'Warning',
          ),
          // An image used as an icon, tinted with the icon color.
          ImageIcon(
            AssetImage('assets/images/leaf.png'),
            size: 48,
            color: Colors.brown,
          ),
        ],
      ),
    );
  }
}
// #enddocregion icons

// #docregion fit
/// What each BoxFit does to the same 64x64 image in a 140x80 box.
class FitDemo extends StatelessWidget {
  const FitDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final fit in const [
          BoxFit.contain,
          BoxFit.cover,
          BoxFit.fill,
          BoxFit.fitWidth,
          BoxFit.fitHeight,
          BoxFit.scaleDown,
        ])
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 70,
                color: Colors.black12,
                child: Image.asset('assets/images/leaf.png', fit: fit),
              ),
              Text(fit.name, style: const TextStyle(fontSize: 11)),
            ],
          ),
      ],
    );
  }
}
// #enddocregion fit

// #docregion svg
const _svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <circle cx="50" cy="50" r="45" fill="#2e7d32"/>
  <path d="M30 55 L45 70 L72 35" stroke="white" stroke-width="9"
        fill="none" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

/// Vector graphics stay sharp at any size (needs the flutter_svg package).
class SvgDemo extends StatelessWidget {
  const SvgDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        SvgPicture.string(_svg, width: 32),
        SvgPicture.string(_svg, width: 96),
        SvgPicture.string(_svg, width: 160),
      ],
    );
  }
}
// #enddocregion svg

// #docregion network
/// A network image with a loading placeholder and an error fallback.
class NetworkPhoto extends StatelessWidget {
  const NetworkPhoto({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      width: 120,
      height: 120,
      fit: BoxFit.cover,
      // frame is null until the first decoded frame is ready, so this shows a
      // spinner while the bytes download and decode.
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return const SizedBox(
          width: 120,
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        );
      },
      // Shown when the request fails or the data is not an image.
      errorBuilder: (context, error, stack) => const SizedBox(
        width: 120,
        height: 120,
        child: Center(child: Icon(Icons.broken_image, size: 48)),
      ),
    );
  }
}
// #enddocregion network
