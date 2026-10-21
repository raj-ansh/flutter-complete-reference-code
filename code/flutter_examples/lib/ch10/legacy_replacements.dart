import 'package:flutter/cupertino.dart' show CupertinoAlertDialog;
import 'package:flutter/material.dart';

// Modern equivalents of APIs used by Flutter 1.x code. Every function in this
// file compiles on Flutter 3.47.6; the old names it replaces do not.

// #docregion buttons
Widget buttons(VoidCallback onTap) {
  return Row(
    children: [
      ElevatedButton(onPressed: onTap, child: const Text('was RaisedButton')),
      TextButton(onPressed: onTap, child: const Text('was FlatButton')),
      OutlinedButton(onPressed: onTap, child: const Text('was OutlineButton')),
    ],
  );
}
// #enddocregion buttons

// #docregion snackbar
void showMessage(BuildContext context) {
  // was: Scaffold.of(context).showSnackBar(...)
  ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('Saved')));
}
// #enddocregion snackbar

// #docregion navbar
BottomNavigationBarItem navItem() {
  // was: BottomNavigationBarItem(icon: ..., title: Text('Home'))
  return const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home');
}
// #enddocregion navbar

// #docregion theme
TextStyle? oldTitleStyle(BuildContext context) {
  // was: Theme.of(context).textTheme.title
  return Theme.of(context).textTheme.titleLarge;
}

TextStyle? oldCounterStyle(BuildContext context) {
  // was: Theme.of(context).textTheme.display1
  return Theme.of(context).textTheme.headlineMedium;
}

Color oldAccent(BuildContext context) {
  // was: Theme.of(context).accentColor
  return Theme.of(context).colorScheme.secondary;
}
// #enddocregion theme

// #docregion misc
Widget backHandler({required Widget child}) {
  // was: WillPopScope(onWillPop: () async => true, child: child)
  return PopScope(canPop: true, child: child);
}

Widget scaledText() {
  // was: Text('x', textScaleFactor: 1.5)
  return const Text('x', textScaler: TextScaler.linear(1.5));
}

int colorAsInt(Color c) {
  // was: c.value
  return c.toARGB32();
}

Widget iosDialog() {
  // was: CupertinoDialog(...)
  return const CupertinoAlertDialog(title: Text('Title'));
}
// #enddocregion misc
