import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session_view_model.dart';

// #docregion banner
/// Says plainly when the live connection is down. It takes no space when
/// everything is fine.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final online = context.select<SessionViewModel, bool>((s) => s.online);
    if (online) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Not connected. Trying to reconnect…',
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// #enddocregion banner
