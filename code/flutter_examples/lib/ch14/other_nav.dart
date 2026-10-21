import 'package:flutter/material.dart';

// #docregion tabs
/// Tabs that swipe, with no routing involved.
class TabsDemo extends StatelessWidget {
  const TabsDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Plants'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.grass), text: 'Herbs'),
              Tab(icon: Icon(Icons.local_florist), text: 'Flowers'),
              Tab(icon: Icon(Icons.park), text: 'Trees'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            Center(child: Text('Basil, mint, thyme')),
            Center(child: Text('Roses, tulips')),
            Center(child: Text('Oak, maple')),
          ],
        ),
      ),
    );
  }
}
// #enddocregion tabs

// #docregion drawer
/// A navigation drawer with a header and destinations.
class DrawerDemo extends StatefulWidget {
  const DrawerDemo({super.key});

  @override
  State<DrawerDemo> createState() => _DrawerDemoState();
}

class _DrawerDemoState extends State<DrawerDemo> {
  int _selected = 0;
  static const _titles = ['Inbox', 'Starred', 'Trash'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_selected])),
      drawer: NavigationDrawer(
        selectedIndex: _selected,
        onDestinationSelected: (i) {
          setState(() => _selected = i);
          Navigator.of(context).pop(); // close the drawer
        },
        children: const [
          Padding(
            padding: EdgeInsets.fromLTRB(28, 16, 16, 10),
            child: Text('Mail'),
          ),
          NavigationDrawerDestination(
            icon: Icon(Icons.inbox),
            label: Text('Inbox'),
          ),
          NavigationDrawerDestination(
            icon: Icon(Icons.star),
            label: Text('Starred'),
          ),
          NavigationDrawerDestination(
            icon: Icon(Icons.delete),
            label: Text('Trash'),
          ),
        ],
      ),
      body: Center(child: Text('Showing ${_titles[_selected]}')),
    );
  }
}
// #enddocregion drawer

// #docregion rail
/// On wide screens a NavigationRail replaces the bottom bar.
class AdaptiveNav extends StatefulWidget {
  const AdaptiveNav({super.key});

  @override
  State<AdaptiveNav> createState() => _AdaptiveNavState();
}

class _AdaptiveNavState extends State<AdaptiveNav> {
  int _index = 0;

  static const _labels = ['Home', 'Search', 'Profile'];
  static const _icons = [Icons.home, Icons.search, Icons.person];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final body = Center(child: Text('Page: ${_labels[_index]}'));
    return Scaffold(
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (var i = 0; i < _labels.length; i++)
                  NavigationRailDestination(
                    icon: Icon(_icons[i]),
                    label: Text(_labels[i]),
                  ),
              ],
            ),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (var i = 0; i < _labels.length; i++)
                  NavigationDestination(
                    icon: Icon(_icons[i]),
                    label: _labels[i],
                  ),
              ],
            ),
    );
  }
}
// #enddocregion rail

// #docregion popscope
/// Asks before leaving a screen with unsaved changes.
class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  bool _dirty = false;

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // While there are unsaved changes the route may not pop by itself.
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Editor')),
        body: Center(
          child: SwitchListTile(
            title: const Text('Unsaved changes'),
            value: _dirty,
            onChanged: (v) => setState(() => _dirty = v),
          ),
        ),
      ),
    );
  }
}
// #enddocregion popscope

// #docregion stepper
/// A multi-step flow with the built-in Stepper.
class StepperDemo extends StatefulWidget {
  const StepperDemo({super.key});

  @override
  State<StepperDemo> createState() => _StepperDemoState();
}

class _StepperDemoState extends State<StepperDemo> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stepper(
        currentStep: _step,
        onStepContinue: _step < 2 ? () => setState(() => _step++) : null,
        onStepCancel: _step > 0 ? () => setState(() => _step--) : null,
        onStepTapped: (i) => setState(() => _step = i),
        steps: [
          Step(
            title: const Text('Account'),
            content: const Text('Choose a name'),
            isActive: _step >= 0,
            state: _step > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Plan'),
            content: const Text('Pick a plan'),
            isActive: _step >= 1,
            state: _step > 1 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Done'),
            content: const Text('Review and finish'),
            isActive: _step >= 2,
          ),
        ],
      ),
    );
  }
}
// #enddocregion stepper
