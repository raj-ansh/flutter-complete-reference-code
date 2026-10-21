import 'package:flutter/material.dart';

import '../audio/sounds.dart';
import '../game/game_controller.dart';
import '../game/high_score_store.dart';
import '../game/world.dart';
import 'game_screen.dart';

// #docregion menu
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key, required this.scores, required this.makeSounds});

  final HighScoreStore scores;

  /// A function, not an object: each game gets its own audio players, which are
  /// released when the game screen is left.
  final GameSounds Function() makeSounds;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  Future<void> _play() async {
    final controller = GameController(
      world: World(seed: DateTime.now().millisecondsSinceEpoch),
      scores: widget.scores,
      sounds: widget.makeSounds(),
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => GameScreen(controller: controller)),
    );
    controller.dispose();
    if (mounted) setState(() {}); // show the new best score
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF16213E),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Skyline Courier',
                style: theme.textTheme.displaySmall?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Deliver the parcels. Mind the towers.',
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 32),
              Text(
                'Best: ${widget.scores.best}',
                style: theme.textTheme.titleLarge?.copyWith(color: Colors.amber),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _play, child: const Text('Play')),
            ],
          ),
        ),
      ),
    );
  }
}
// #enddocregion menu
