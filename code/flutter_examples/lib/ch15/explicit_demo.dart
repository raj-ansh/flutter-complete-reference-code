import 'package:flutter/material.dart';

// #docregion pulse
/// An explicit animation: you own the AnimationController.
class PulsingHeart extends StatefulWidget {
  const PulsingHeart({super.key});

  @override
  State<PulsingHeart> createState() => PulsingHeartState();
}

// SingleTickerProviderStateMixin supplies the "vsync": a source of ticks
// tied to the screen refresh, so the animation stops when the widget is
// not visible.
class PulsingHeartState extends State<PulsingHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  late final Animation<double> scale = Tween<double>(
    begin: 1,
    end: 1.4,
  ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
    controller.repeat(reverse: true); // grow, shrink, grow, ...
  }

  @override
  void dispose() {
    controller.dispose(); // always release the controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      // AnimatedBuilder rebuilds only this subtree on every tick.
      child: AnimatedBuilder(
        animation: scale,
        builder: (context, child) =>
            Transform.scale(scale: scale.value, child: child),
        child: const Icon(Icons.favorite, color: Colors.red, size: 64),
      ),
    );
  }
}
// #enddocregion pulse

// #docregion transitions
/// Ready-made transition widgets take an Animation directly.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key});

  @override
  State<FadeSlideIn> createState() => FadeSlideInState();
}

class FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  late final Animation<double> opacity = CurvedAnimation(
    parent: controller,
    curve: Curves.easeOut,
  );

  late final Animation<Offset> slide = Tween<Offset>(
    begin: const Offset(0, 0.5), // half its own height below
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FadeTransition(
          opacity: opacity,
          child: SlideTransition(
            position: slide,
            child: const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Hello, animation'),
              ),
            ),
          ),
        ),
        FilledButton(
          onPressed: () => controller.status == AnimationStatus.completed
              ? controller.reverse()
              : controller.forward(),
          child: const Text('Play'),
        ),
      ],
    );
  }
}
// #enddocregion transitions

// #docregion staggered
/// One controller, several animations, each on its own part of the timeline.
class StaggeredBars extends StatefulWidget {
  const StaggeredBars({super.key});

  @override
  State<StaggeredBars> createState() => StaggeredBarsState();
}

class StaggeredBarsState extends State<StaggeredBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  // Interval(begin, end) uses fractions of the controller's duration.
  late final List<Animation<double>> bars = [
    for (var i = 0; i < 3; i++)
      CurvedAnimation(
        parent: controller,
        curve: Interval(i * 0.25, 0.5 + i * 0.25, curve: Curves.easeOut),
      ),
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final bar in bars)
          AnimatedBuilder(
            animation: bar,
            builder: (context, _) => Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              width: 40 + 200 * bar.value,
              height: 24,
              color: Colors.teal,
            ),
          ),
        FilledButton(onPressed: controller.forward, child: const Text('Start')),
      ],
    );
  }
}
// #enddocregion staggered
