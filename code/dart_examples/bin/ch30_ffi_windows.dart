// Chapter 30: calling a function in a native library with dart:ffi.
// This example is for Windows only: it calls GetTickCount64 from kernel32.dll,
// which returns the milliseconds since the computer started.
import 'dart:ffi';
import 'dart:io';

// #docregion ffi
// The C signature:  ULONGLONG GetTickCount64(void);
typedef _NativeTick = Uint64 Function(); // how C sees the function
typedef _DartTick = int Function(); // how Dart sees it

void main() {
  if (!Platform.isWindows) {
    print('This example calls a Windows library; skipped on ${Platform.operatingSystem}.');
    return;
  }
  // Open the library, look the function up by name, and give it a Dart type.
  final kernel32 = DynamicLibrary.open('kernel32.dll');
  final getTickCount64 = kernel32.lookupFunction<_NativeTick, _DartTick>('GetTickCount64');

  final milliseconds = getTickCount64();
  final uptime = Duration(milliseconds: milliseconds);
  print('GetTickCount64() returned $milliseconds');
  print('that is ${uptime.inHours} hours and ${uptime.inMinutes % 60} minutes since start-up');
}
// #enddocregion ffi
