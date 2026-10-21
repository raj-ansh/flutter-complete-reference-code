import 'package:flutter/material.dart';

// #docregion implicit
/// Implicit animations: change the target value and Flutter animates to it.
class ImplicitDemo extends StatefulWidget {
  const ImplicitDemo({super.key, this.curve = Curves.easeInOut});

  final Curve curve;

  @override
  State<ImplicitDemo> createState() => ImplicitDemoState();
}

class ImplicitDemoState extends State<ImplicitDemo> {
  bool expanded = false;

  void toggle() => setState(() => expanded = !expanded);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Size, color and shape animate together over one second.
        AnimatedContainer(
          key: const Key('box'),
          duration: const Duration(seconds: 1),
          curve: widget.curve,
          width: expanded ? 200 : 100,
          height: 100,
          decoration: BoxDecoration(
            color: expanded ? Colors.deepOrange : Colors.indigo,
            borderRadius: BorderRadius.circular(expanded ? 50 : 8),
          ),
        ),
        const SizedBox(height: 16),
        // Fades its child to a new opacity.
        AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: expanded ? 1 : 0.2,
          child: const Text('Now you see it'),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: toggle, child: const Text('Toggle')),
      ],
    );
  }
}
// #enddocregion implicit

// #docregion switcher
/// AnimatedSwitcher cross-fades when its child is replaced by a different
/// widget. The key tells it that the child really changed.
class SwitcherDemo extends StatefulWidget {
  const SwitcherDemo({super.key});

  @override
  State<SwitcherDemo> createState() => _SwitcherDemoState();
}

class _SwitcherDemoState extends State<SwitcherDemo> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: Text(
            '$_count',
            // Without a changing key, Flutter sees "a Text" before and after
            // and does not animate.
            key: ValueKey(_count),
            style: Theme.of(context).textTheme.displayMedium,
          ),
        ),
        FilledButton(
          onPressed: () => setState(() => _count++),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
// #enddocregion switcher

// #docregion tween
/// TweenAnimationBuilder: animate any value when you have no controller.
class SpinningStar extends StatelessWidget {
  const SpinningStar({super.key, required this.turns});

  final double turns;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: turns), // starts from the previous end value
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, value, child) =>
          Transform.rotate(angle: value * 2 * 3.14159265, child: child),
      child: const Icon(Icons.star, size: 64, color: Colors.amber),
    );
  }
}
// #enddocregion tween
