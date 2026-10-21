import 'package:flutter/material.dart';

// #docregion dragdrop
/// Drag a plant onto the pot.
class DragDropDemo extends StatefulWidget {
  const DragDropDemo({super.key});

  @override
  State<DragDropDemo> createState() => _DragDropDemoState();
}

class _DragDropDemoState extends State<DragDropDemo> {
  String _planted = 'The pot is empty';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The thing you pick up. `data` travels with it.
          Draggable<String>(
            data: 'Basil',
            // What follows the finger while dragging.
            feedback: const Material(
              color: Colors.transparent,
              child: Chip(label: Text('Basil')),
            ),
            // What stays behind at the starting place.
            childWhenDragging: const Opacity(
              opacity: 0.3,
              child: Chip(label: Text('Basil')),
            ),
            child: const Chip(label: Text('Basil')),
          ),
          const SizedBox(height: 48),
          // The place you drop it.
          DragTarget<String>(
            onWillAcceptWithDetails: (details) => details.data == 'Basil',
            onAcceptWithDetails: (details) =>
                setState(() => _planted = '${details.data} planted'),
            builder: (context, candidates, rejected) {
              final hovering = candidates.isNotEmpty;
              return Container(
                width: 140,
                height: 90,
                decoration: BoxDecoration(
                  color: hovering
                      ? Colors.green.shade200
                      : Colors.brown.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(width: hovering ? 3 : 1),
                ),
                alignment: Alignment.center,
                child: Text(_planted, textAlign: TextAlign.center),
              );
            },
          ),
        ],
      ),
    );
  }
}
// #enddocregion dragdrop
