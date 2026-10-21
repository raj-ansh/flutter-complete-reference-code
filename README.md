# Flutter: The Complete Reference: code companion

This repository holds the code of the book *Flutter: The Complete Reference* by Rajkumar Panda: every example, the three projects (Pocket Organizer, Relay, Skyline Courier), their tests, and the real outputs the book quotes.

Repository: https://github.com/raj-ansh/flutter-complete-reference-code

## What is here

| Folder (under `code/`) | Chapters | What it is |
|---|---|---|
| `dart_examples` | 4–7, 28, 30, 32 | Command-line Dart programs |
| `flutter_examples` | 8–21, 27, 28, 30, 31 | Small Flutter examples with tests, by chapter (`lib/chNN`, `test/chNN`) |
| `first_app` | 3 | The generated counter app |
| `pocket_organizer` | 22, 23, 27, 28, 32 | Project 1: notes, tasks, appointments and contacts (SQLite) |
| `relay_server` | 24, 29 | Project 2: Node.js chat server (Socket.IO, Argon2id) |
| `relay_app` | 25 | Project 2: the Flutter chat client |
| `skyline_courier` | 26 | Project 3: a game drawn in code |
| `realtime_demo` | 21 | Minimal Socket.IO server used by Chapter 21's tests |
| `tls_demo` | 29 | Self-signed HTTPS demonstration |
| `l10n_demo` | 31 | Generated localization (English, Spanish, Arabic) |
| `web_demo` | 33 | A page of platform facts, built for the web (JavaScript and WebAssembly) |
| `snapshots` | 22 | Frozen copies of files that Chapter 22 quotes (not a runnable project) |
| `captured` | all | The real outputs and logs the book includes |

## Versions the code was tested with

Flutter 3.47.6 (stable) and Dart 3.13.5; Node.js 24.18.0 (the Relay server needs 24.7 or later for the built-in Argon2); Windows 11. The full list of package versions is Appendix E of the book, and each project's `pubspec.lock` or `package-lock.json` pins them. Newer versions may need small changes.

## Running things

Each Flutter project:

```text
cd code/<project>
flutter pub get
flutter test
```

The Relay server:

```text
cd code/relay_server
npm install
npm test            # node --test
node src/main.js 3000
```

Run Flutter commands one at a time; two at once can wait on the tool's lock. Android builds need the Android SDK (see Chapter 2). `relay_app`'s end-to-end tests start the real server with `node`, so install the server's packages first.

## What was and was not tested

The tests, builds and outputs were run on one Windows computer. Nothing was run on a physical phone or emulator, nothing was built for iOS or macOS, and no Windows desktop app was built (no Visual Studio). The book says so wherever it matters; read its preface ("What was tested, and what was not") before relying on any platform behavior.

## Things deliberately not in this repository

- Signing keys and `key.properties` (a `key.properties.example` shows the format). Never commit a real keystore.
- Build output and downloaded packages (`build/`, `.dart_tool/`, `node_modules/`): recreate them with the commands above.
- Local tool files (`local.properties`, `.flutter-plugins-dependencies`, generated iOS files that contain machine paths): Flutter recreates them.

## License

**To be added by the author.** Until a license file is added, all rights are reserved. See the book's copyright page.

## Reporting a problem

If an example does not run, open an issue with your Flutter/Dart (or Node) version, the command you ran and the full output.
