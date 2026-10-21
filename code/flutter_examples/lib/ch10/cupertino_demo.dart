import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as m;

// #docregion cupertino
/// A settings screen built from Cupertino widgets.
class CupertinoSettings extends StatefulWidget {
  const CupertinoSettings({super.key});

  @override
  State<CupertinoSettings> createState() => _CupertinoSettingsState();
}

class _CupertinoSettingsState extends State<CupertinoSettings> {
  bool _notifications = true;
  double _volume = 0.6;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: const CupertinoThemeData(
        primaryColor: CupertinoColors.systemIndigo,
      ),
      home: CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(middle: Text('Settings')),
        child: SafeArea(
          child: ListView(
            children: [
              CupertinoListSection.insetGrouped(
                header: const Text('Alerts'),
                children: [
                  CupertinoListTile(
                    title: const Text('Notifications'),
                    trailing: CupertinoSwitch(
                      value: _notifications,
                      onChanged: (v) => setState(() => _notifications = v),
                    ),
                  ),
                  CupertinoListTile(
                    title: const Text('Volume'),
                    additionalInfo: Text('${(_volume * 100).round()}%'),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: CupertinoSlider(
                  value: _volume,
                  onChanged: (v) => setState(() => _volume = v),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: CupertinoButton.filled(
                  onPressed: () {},
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// #enddocregion cupertino

// #docregion adaptive
/// One widget, drawn in each platform's style by `.adaptive`.
class AdaptiveSwitchDemo extends StatelessWidget {
  const AdaptiveSwitchDemo({super.key, required this.platform});

  final TargetPlatform platform;

  @override
  Widget build(BuildContext context) {
    return m.MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: m.ThemeData(platform: platform),
      home: m.Scaffold(
        body: m.Center(
          child: m.Switch.adaptive(value: true, onChanged: (_) {}),
        ),
      ),
    );
  }
}
// #enddocregion adaptive

String platformOf(BuildContext context) => m.Theme.of(context).platform.name;
