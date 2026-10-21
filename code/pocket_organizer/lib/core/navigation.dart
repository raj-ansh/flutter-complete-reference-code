import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

// #docregion closeeditor
extension CloseEditor on BuildContext {
  /// Leaves an editor screen. Normally that means going back, but when the app
  /// was opened straight onto the editor (a link, a notification, a restored
  /// session) there is nothing to go back to, and `pop()` would throw. Then go
  /// to [fallback], the screen the editor belongs to.
  void closeEditor(String fallback) {
    if (canPop()) {
      pop();
    } else {
      go(fallback);
    }
  }
}
// #enddocregion closeeditor
