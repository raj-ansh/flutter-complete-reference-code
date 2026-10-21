import 'package:flutter/material.dart';

// #docregion hero
/// A Hero flies a widget from one screen to the next when both screens have
/// a Hero with the same tag.
class HeroList extends StatelessWidget {
  const HeroList({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plants')),
      body: ListView(
        children: [
          for (final name in const ['Basil', 'Mint'])
            ListTile(
              leading: Hero(
                tag: 'plant-$name', // must be unique per screen, same on both
                child: CircleAvatar(child: Text(name[0])),
              ),
              title: Text(name),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => HeroDetail(name: name)),
              ),
            ),
        ],
      ),
    );
  }
}

class HeroDetail extends StatelessWidget {
  const HeroDetail({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Center(
        child: Hero(
          tag: 'plant-$name',
          child: CircleAvatar(radius: 60, child: Text(name[0])),
        ),
      ),
    );
  }
}
// #enddocregion hero
