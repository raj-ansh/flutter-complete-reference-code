import 'package:flutter/material.dart';

// #docregion bad
/// A like button with accessibility problems, on purpose: it has no label (an
/// icon alone says nothing to a screen reader) and its tap target is 24 by 24
/// logical pixels.
class CarelessLikeButton extends StatelessWidget {
  const CarelessLikeButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: Icon(Icons.favorite_border, size: 20),
      ),
    );
  }
}
// #enddocregion bad

// #docregion good
/// The same control, repaired: IconButton brings a 48 by 48 target, the
/// tooltip is also the label a screen reader speaks, and the state is
/// described in words.
class LikeButton extends StatelessWidget {
  const LikeButton({super.key, required this.liked, required this.onChanged});
  final bool liked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: liked ? 'Remove like' : 'Like',
      isSelected: liked,
      icon: const Icon(Icons.favorite_border),
      selectedIcon: const Icon(Icons.favorite),
      onPressed: () => onChanged(!liked),
    );
  }
}
// #enddocregion good

// #docregion rating
/// A custom control built from scratch, so the framework knows nothing about
/// it: Semantics supplies the meaning. A screen reader user hears the label and
/// value, and can swipe up or down to change it (increase and decrease).
class RatingBar extends StatelessWidget {
  const RatingBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.max = 5,
  });
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Rating',
      value: '$value of $max',
      increasedValue: '${(value + 1).clamp(0, max)} of $max',
      decreasedValue: '${(value - 1).clamp(0, max)} of $max',
      onIncrease: value < max ? () => onChanged(value + 1) : null,
      onDecrease: value > 0 ? () => onChanged(value - 1) : null,
      // The stars are decoration for sighted users; hide them from the tree so
      // a screen reader does not read five unnamed images as well.
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= max; i++)
              GestureDetector(
                onTap: () => onChanged(i),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    i <= value ? Icons.star : Icons.star_border,
                    size: 32,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
// #enddocregion rating
