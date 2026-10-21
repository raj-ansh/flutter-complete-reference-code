import 'package:flutter/material.dart';

class OldRadio extends StatelessWidget {
  const OldRadio({super.key});

  @override
  Widget build(BuildContext context) {
    return Radio<int>(value: 1, groupValue: 1, onChanged: (v) {});
  }
}
