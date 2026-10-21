// #docregion flow
/// What the operating system can answer when you ask for a permission.
enum PermissionState { granted, denied, permanentlyDenied }

/// The only thing the app knows about permissions. A real implementation wraps
/// a plugin; tests use a fake.
abstract interface class PermissionGateway {
  Future<PermissionState> status();
  Future<PermissionState> request();
}

/// What the screen should do next.
sealed class Access {
  const Access();
}

class Allowed extends Access {
  const Allowed();
}

/// Explain why we need it, then let the user try again.
class AskAgain extends Access {
  const AskAgain();
}

/// The system will no longer show its dialog: send the user to Settings.
class SendToSettings extends Access {
  const SendToSettings();
}

class PermissionFlow {
  PermissionFlow(this._gateway);
  final PermissionGateway _gateway;

  /// Ask only when needed, and never ask a second time when the system has
  /// already said it will not show the dialog again.
  Future<Access> ensure() async {
    var state = await _gateway.status();
    if (state == PermissionState.denied) {
      state = await _gateway.request();
    }
    return switch (state) {
      PermissionState.granted => const Allowed(),
      PermissionState.denied => const AskAgain(),
      PermissionState.permanentlyDenied => const SendToSettings(),
    };
  }
}
// #enddocregion flow
