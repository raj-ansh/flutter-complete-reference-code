import 'package:flutter/material.dart';

// #docregion transform
/// The same 100 x 40 box, changed four ways. Which of them changes how much
/// room the box takes in the layout, and which only changes how it is painted?
class TransformGallery extends StatelessWidget {
  const TransformGallery({super.key});

  static const box = SizedBox(
    width: 100,
    height: 40,
    child: ColoredBox(color: Colors.teal),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Painted rotated; the layout still reserves 100 x 40.
        Transform.rotate(key: const Key('transform'), angle: 0.5, child: box),
        // Rotated in the layout: the space becomes 40 x 100.
        const RotatedBox(key: Key('rotated'), quarterTurns: 1, child: box),
        // Painted at half strength; same space.
        const Opacity(key: Key('opacity'), opacity: 0.5, child: box),
        // The corners are cut off; same space.
        const ClipRRect(
          key: Key('clip'),
          borderRadius: BorderRadius.all(Radius.circular(20)),
          child: box,
        ),
      ],
    );
  }
}
// #enddocregion transform
