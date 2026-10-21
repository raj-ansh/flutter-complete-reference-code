import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/game_controller.dart';
import '../game/game_painter.dart';
import '../game/world.dart';

// #docregion gamescreen
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.controller});
  final GameController controller;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_syncTicker);
    _syncTicker();
  }

  /// The Ticker is the heartbeat of the game: it calls us once per frame with
  /// the time since it started. It runs only while the game is actually
  /// running. While waiting for the first tap, paused, or over, no frames are
  /// requested at all, which saves battery.
  void _syncTicker() {
    final controller = widget.controller;
    final shouldRun = controller.world.status == GameStatus.running && !controller.paused;
    if (shouldRun && !_ticker.isActive) {
      _last = Duration.zero; // a restarted ticker counts from zero again
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final frameTime = elapsed - _last;
    _last = elapsed;
    widget.controller.advance(frameTime);
  }

  /// If the app goes to the background (a call, the home button), pause
  /// instead of letting the courier fall to the ground unseen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) widget.controller.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_syncTicker);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      body: SafeArea(
        child: Center(
          // The playfield is always 360 x 640 units. FittedBox scales it to
          // the screen, keeping its shape, and taps are scaled back for us.
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: Tuning.width,
              height: Tuning.height,
              child: ClipRect(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => controller.tap(), // on touch, not on release
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(painter: GamePainter(controller)),
                        ),
                      ),
                      // The overlays DO rebuild, but only when the controller
                      // changes, and they are small.
                      ListenableBuilder(
                        listenable: controller,
                        builder: (context, _) => _Overlay(controller: controller),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final world = controller.world;
    final style = Theme.of(context).textTheme;
    const shadow = [Shadow(blurRadius: 4, color: Colors.black54)];
    return Stack(
      children: [
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              '${world.score}',
              style: style.displayMedium?.copyWith(color: Colors.white, shadows: shadow),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 8,
          child: IconButton(
            tooltip: controller.paused ? 'Resume' : 'Pause',
            color: Colors.white,
            icon: Icon(controller.paused ? Icons.play_arrow : Icons.pause),
            onPressed: controller.paused ? controller.resume : controller.pause,
          ),
        ),
        if (world.status == GameStatus.ready)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Text(
                  'Tap to fly',
                  style: style.headlineSmall?.copyWith(color: Colors.white, shadows: shadow),
                ),
              ),
            ),
          ),
        if (controller.paused) _Panel(title: 'Paused', controller: controller, resume: true),
        if (world.status == GameStatus.over)
          _Panel(title: 'Crashed', controller: controller, resume: false),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.controller, required this.resume});
  final String title;
  final GameController controller;
  final bool resume;

  @override
  Widget build(BuildContext context) {
    final world = controller.world;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text('Score ${world.score}'),
                  Text(
                    controller.newRecord ? 'New best!' : 'Best ${controller.best}',
                    style: TextStyle(
                      fontWeight: controller.newRecord ? FontWeight.bold : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: resume ? controller.resume : controller.restart,
                    child: Text(resume ? 'Resume' : 'Try again'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Menu'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
// #enddocregion gamescreen
