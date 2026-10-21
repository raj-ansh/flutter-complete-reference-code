import 'package:flutter/material.dart';

enum NoteAction { rename, share, delete }

// #docregion popup
/// The classic "three dots" overflow menu.
class PopupDemo extends StatefulWidget {
  const PopupDemo({super.key});

  @override
  State<PopupDemo> createState() => _PopupDemoState();
}

class _PopupDemoState extends State<PopupDemo> {
  String _last = 'No action yet';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Note'),
        actions: [
          PopupMenuButton<NoteAction>(
            tooltip: 'More options',
            onSelected: (action) => setState(() => _last = action.name),
            itemBuilder: (context) => const [
              PopupMenuItem(value: NoteAction.rename, child: Text('Rename')),
              PopupMenuItem(value: NoteAction.share, child: Text('Share')),
              PopupMenuDivider(),
              PopupMenuItem(value: NoteAction.delete, child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: Center(child: Text('Last action: $_last')),
    );
  }
}
// #enddocregion popup

// #docregion menuanchor
/// MenuAnchor: menus with submenus and keyboard support, for desktop and web.
class MenuAnchorDemo extends StatefulWidget {
  const MenuAnchorDemo({super.key});

  @override
  State<MenuAnchorDemo> createState() => _MenuAnchorDemoState();
}

class _MenuAnchorDemoState extends State<MenuAnchorDemo> {
  String _chosen = 'nothing';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MenuAnchor(
              menuChildren: [
                MenuItemButton(
                  onPressed: () => setState(() => _chosen = 'New'),
                  child: const Text('New'),
                ),
                SubmenuButton(
                  menuChildren: [
                    MenuItemButton(
                      onPressed: () => setState(() => _chosen = 'PDF'),
                      child: const Text('PDF'),
                    ),
                    MenuItemButton(
                      onPressed: () => setState(() => _chosen = 'Text'),
                      child: const Text('Text'),
                    ),
                  ],
                  child: const Text('Export'),
                ),
              ],
              builder: (context, controller, child) => FilledButton(
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
                child: const Text('File'),
              ),
            ),
            Text('Chose: $_chosen'),
          ],
        ),
      ),
    );
  }
}
// #enddocregion menuanchor

// #docregion progress
/// Progress indicators. Give `value` for determinate progress; leave it out
/// when you cannot know how long the work will take.
class ProgressDemo extends StatelessWidget {
  const ProgressDemo({super.key, this.value = 0.6});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Indeterminate (unknown duration)'),
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
          const SizedBox(height: 24),
          Text('Determinate: ${(value * 100).round()}%'),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: value),
          const SizedBox(height: 24),
          Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 24),
              CircularProgressIndicator(value: value),
              const SizedBox(width: 24),
              // Draws the style of the current platform (Cupertino on iOS).
              const CircularProgressIndicator.adaptive(),
            ],
          ),
        ],
      ),
    );
  }
}
// #enddocregion progress

// #docregion tooltip
/// A tooltip describes a control; long-press (or hover) to see it.
class TooltipDemo extends StatelessWidget {
  const TooltipDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: IconButton(
        tooltip: 'Add to favorites',
        icon: const Icon(Icons.favorite_border),
        onPressed: () {},
      ),
    );
  }
}
// #enddocregion tooltip
