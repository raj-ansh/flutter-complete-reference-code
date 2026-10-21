import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// #docregion gallery
/// Common TextField decorations and input restrictions.
class FieldGallery extends StatelessWidget {
  const FieldGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Outlined, with a helper line and an icon.
        const TextField(
          decoration: InputDecoration(
            labelText: 'Full name',
            helperText: 'As it appears on your ID',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        // Filled style with an error message.
        const TextField(
          decoration: InputDecoration(
            labelText: 'Username',
            errorText: 'That name is taken',
            filled: true,
          ),
        ),
        const SizedBox(height: 16),
        // Digits only, at most 4 characters, with a counter.
        TextField(
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          maxLength: 4,
          decoration: const InputDecoration(
            labelText: 'PIN',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        // Several lines of text.
        const TextField(
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Notes',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        // A hint disappears as soon as the user types; a label stays.
        const TextField(
          decoration: InputDecoration(
            hintText: 'Search the garden',
            prefixIcon: Icon(Icons.search),
            suffixIcon: Icon(Icons.mic),
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
// #enddocregion gallery

// #docregion counter
/// Reacts to every keystroke without calling setState, using the fact that
/// a TextEditingController is a ValueListenable.
class LiveCounter extends StatefulWidget {
  const LiveCounter({super.key});

  @override
  State<LiveCounter> createState() => _LiveCounterState();
}

class _LiveCounterState extends State<LiveCounter> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _controller,
          decoration: const InputDecoration(labelText: 'Tweet-sized note'),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            final left = 40 - value.text.length;
            return Text(
              '$left characters left',
              style: TextStyle(color: left < 0 ? Colors.red : null),
            );
          },
        ),
      ],
    );
  }
}
// #enddocregion counter
