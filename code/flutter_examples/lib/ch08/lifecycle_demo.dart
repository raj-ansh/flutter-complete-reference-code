import 'package:flutter/widgets.dart';

// #docregion probe
/// A widget that records each lifecycle method as it runs.
class LifecycleProbe extends StatefulWidget {
  const LifecycleProbe({super.key, required this.label, required this.log});

  final String label;
  final List<String> log;

  @override
  State<LifecycleProbe> createState() => _LifecycleProbeState();
}

class _LifecycleProbeState extends State<LifecycleProbe> {
  int _taps = 0;

  @override
  void initState() {
    super.initState();
    widget.log.add('initState');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.log.add('didChangeDependencies');
  }

  @override
  void didUpdateWidget(LifecycleProbe oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.log.add('didUpdateWidget (${oldWidget.label} -> ${widget.label})');
  }

  @override
  void deactivate() {
    widget.log.add('deactivate');
    super.deactivate();
  }

  @override
  void dispose() {
    widget.log.add('dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.log.add('build');
    return Directionality(
      textDirection: TextDirection.ltr,
      child: GestureDetector(
        onTap: () {
          widget.log.add('onTap');
          setState(() => _taps++);
        },
        child: Text('${widget.label}: $_taps'),
      ),
    );
  }
}
// #enddocregion probe
