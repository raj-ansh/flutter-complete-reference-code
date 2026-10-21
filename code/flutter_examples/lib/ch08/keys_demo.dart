import 'package:flutter/widgets.dart';

// #docregion tile
/// A tile that remembers how many times it was tapped.
class CountTile extends StatefulWidget {
  const CountTile({super.key, required this.label});

  final String label;

  @override
  State<CountTile> createState() => _CountTileState();
}

class _CountTileState extends State<CountTile> {
  int _taps = 0; // state that belongs to this particular tile

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _taps++),
      child: Text('${widget.label}:$_taps'),
    );
  }
}
// #enddocregion tile

// #docregion swap
/// Shows two tiles and a button that reverses their order.
class SwapDemo extends StatefulWidget {
  const SwapDemo({super.key, required this.useKeys});

  final bool useKeys;

  @override
  State<SwapDemo> createState() => _SwapDemoState();
}

class _SwapDemoState extends State<SwapDemo> {
  List<String> labels = ['A', 'B'];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          for (final label in labels)
            CountTile(
              // With a key, Flutter can tell which tile is which after a reorder.
              key: widget.useKeys ? ValueKey(label) : null,
              label: label,
            ),
          GestureDetector(
            key: const Key('swap'),
            onTap: () => setState(() => labels = labels.reversed.toList()),
            child: const Text('swap'),
          ),
        ],
      ),
    );
  }
}
// #enddocregion swap
