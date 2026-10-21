import '../ch17/pantry_model.dart';
import 'data.dart';

// #docregion state
/// What the screen can be showing. A sealed class makes the compiler check
/// that every case is handled, and an impossible mix (loading AND an error)
/// cannot be represented.
sealed class PantryState {
  const PantryState();
}

final class PantryLoading extends PantryState {
  const PantryLoading();
}

final class PantryLoaded extends PantryState {
  const PantryLoaded(this.items, {this.message});
  final List<PantryItem> items;

  /// A problem with the last action, shown without hiding the list.
  final String? message;
}

final class PantryFailed extends PantryState {
  const PantryFailed(this.message);
  final String message;
}
// #enddocregion state

// #docregion fromresult
/// The one rule shared by the view-model and Bloc versions: success shows the
/// new list; failure keeps an already shown list and reports the problem.
PantryState stateFromResult(
  PantryState previous,
  Result<List<PantryItem>> result,
) {
  return switch (result) {
    Ok(:final value) => PantryLoaded(value),
    Err(:final message) => switch (previous) {
      PantryLoaded(:final items) => PantryLoaded(items, message: message),
      _ => PantryFailed(message),
    },
  };
}
// #enddocregion fromresult
