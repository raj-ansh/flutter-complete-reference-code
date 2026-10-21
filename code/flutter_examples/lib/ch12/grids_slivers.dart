import 'package:flutter/material.dart';

Color _tileColor(int i) =>
    Colors.primaries[i % Colors.primaries.length].shade400;

// #docregion grids
/// Three ways to size a grid.
class GridsDemo extends StatelessWidget {
  const GridsDemo({super.key});

  Widget _tile(int i) => Container(
    color: _tileColor(i),
    alignment: Alignment.center,
    child: Text('$i', style: const TextStyle(color: Colors.white)),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('GridView.count: exactly 3 columns'),
        SizedBox(
          height: 130,
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            padding: const EdgeInsets.all(4),
            children: [for (var i = 0; i < 6; i++) _tile(i)],
          ),
        ),
        const Text('GridView.extent: tiles at most 80 wide'),
        SizedBox(
          height: 130,
          child: GridView.extent(
            maxCrossAxisExtent: 80,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            padding: const EdgeInsets.all(4),
            children: [for (var i = 0; i < 8; i++) _tile(i)],
          ),
        ),
        const Text('GridView.builder: lazy, 2:1 tiles'),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: 1000,
            itemBuilder: (context, i) => _tile(i),
          ),
        ),
      ],
    );
  }
}
// #enddocregion grids

// #docregion slivers
/// A scrolling page made of slivers: a collapsing bar, a header, a grid
/// and a list, all scrolling together as one.
class SliverPage extends StatelessWidget {
  const SliverPage({super.key, this.controller});

  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: controller,
        slivers: [
          SliverAppBar(
            pinned: true, // stays visible, collapsed, when scrolled away
            expandedHeight: 160,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Garden'),
              background: Container(color: Colors.green.shade700),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Favorites'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverGrid.count(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (var i = 0; i < 6; i++)
                  Container(
                    color: _tileColor(i),
                    alignment: Alignment.center,
                    child: Text('$i'),
                  ),
              ],
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('All plants'),
            ),
          ),
          SliverList.builder(
            itemCount: 30,
            itemBuilder: (context, i) => ListTile(title: Text('Plant $i')),
          ),
        ],
      ),
    );
  }
}
// #enddocregion slivers

// #docregion pageview
/// Swipe sideways between full-size pages.
class PagesDemo extends StatefulWidget {
  const PagesDemo({super.key});

  @override
  State<PagesDemo> createState() => _PagesDemoState();
}

class _PagesDemoState extends State<PagesDemo> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  color: _tileColor(i * 3),
                  alignment: Alignment.center,
                  child: Text(
                    'Page ${i + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _page ? Colors.black : Colors.black26,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
// #enddocregion pageview
