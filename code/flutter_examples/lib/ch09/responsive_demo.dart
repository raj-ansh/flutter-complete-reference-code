import 'package:flutter/material.dart';

import 'box.dart';

// #docregion responsive
/// Chooses a layout from the width it is given.
class ResponsiveDemo extends StatelessWidget {
  const ResponsiveDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        const list = Box('list', color: Colors.teal);
        const detail = Box('detail', color: Colors.deepOrange);
        if (wide) {
          // Side by side: list takes one third, detail two thirds.
          return Row(
            children: [
              const Expanded(flex: 1, child: list),
              const SizedBox(width: 8),
              const Expanded(flex: 2, child: detail),
            ],
          );
        }
        // Stacked on narrow screens.
        return Column(
          children: [
            const Expanded(child: list),
            const SizedBox(height: 8),
            const Expanded(child: detail),
          ],
        );
      },
    );
  }
}
// #enddocregion responsive

// #docregion safearea
/// Content kept out of areas the system uses (status bar, notch, gesture bar).
class SafeAreaDemo extends StatelessWidget {
  const SafeAreaDemo({super.key, required this.safe});

  final bool safe;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      color: Colors.teal,
      alignment: Alignment.topCenter,
      child: const Text(
        'Top of my content',
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        // Pretend the device has a tall status bar and a gesture bar.
        data: const MediaQueryData(
          size: Size(360, 640),
          padding: EdgeInsets.only(top: 44, bottom: 34),
        ),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: safe ? SafeArea(child: content) : content,
        ),
      ),
    );
  }
}
// #enddocregion safearea
