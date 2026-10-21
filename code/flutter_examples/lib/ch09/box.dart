import 'package:flutter/material.dart';

/// A colored, labelled rectangle used throughout the layout examples.
class Box extends StatelessWidget {
  const Box(
    this.label, {
    super.key,
    this.color = Colors.indigo,
    this.width,
    this.height,
  });

  final String label;
  final Color color;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: color,
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Wraps an example so a screenshot has a neutral background and a margin.
class DemoFrame extends StatelessWidget {
  const DemoFrame({super.key, required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.teal)),
      home: Scaffold(
        backgroundColor: const Color(0xFFF4F4F4),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: .start,
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      title!,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
