import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio/sounds.dart';
import 'game/high_score_store.dart';
import 'ui/menu_screen.dart';

// #docregion main
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // A game is played one way up.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final scores = await PrefsHighScoreStore.open();
  runApp(SkylineCourierApp(scores: scores, makeSounds: AudioplayersSounds.new));
}

class SkylineCourierApp extends StatelessWidget {
  const SkylineCourierApp({super.key, required this.scores, required this.makeSounds});
  final HighScoreStore scores;
  final GameSounds Function() makeSounds;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skyline Courier',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.amber, brightness: Brightness.dark),
      ),
      home: MenuScreen(scores: scores, makeSounds: makeSounds),
    );
  }
}
// #enddocregion main
