import 'package:flutter/material.dart';

// #docregion gestures
/// One box that reacts to tap, double tap, long press and drag.
class GestureBox extends StatefulWidget {
  const GestureBox({super.key});

  @override
  State<GestureBox> createState() => _GestureBoxState();
}

class _GestureBoxState extends State<GestureBox> {
  Offset _offset = Offset.zero;
  bool _big = false;
  Color _color = Colors.indigo;
  String _last = 'nothing yet';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(padding: const EdgeInsets.all(12), child: Text('Last: $_last')),
        Expanded(
          child: Stack(
            children: [
              Positioned(
                left: 60 + _offset.dx,
                top: 40 + _offset.dy,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _color = _color == Colors.indigo
                        ? Colors.deepOrange
                        : Colors.indigo;
                    _last = 'tap';
                  }),
                  onDoubleTap: () => setState(() {
                    _big = !_big;
                    _last = 'double tap';
                  }),
                  onLongPress: () => setState(() {
                    _offset = Offset.zero;
                    _last = 'long press (reset)';
                  }),
                  // A pan is a drag in any direction.
                  onPanUpdate: (details) => setState(() {
                    _offset += details.delta;
                    _last = 'drag';
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: _big ? 160 : 100,
                    height: _big ? 160 : 100,
                    color: _color,
                    alignment: Alignment.center,
                    child: const Text(
                      'touch me',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
// #enddocregion gestures

// #docregion ink
/// InkWell draws the Material ripple. It needs a Material ancestor (a Card,
/// Scaffold, Material...) to paint on.
class RippleCard extends StatelessWidget {
  const RippleCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias, // keeps the ripple inside rounded corners
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Tap for a ripple'),
        ),
      ),
    );
  }
}
// #enddocregion ink
