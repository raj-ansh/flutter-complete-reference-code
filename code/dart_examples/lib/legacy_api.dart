// #docregion deprecated
/// The old name, kept for existing callers.
@Deprecated('Use distance() from geometry.dart instead.')
double dist(double dx, double dy) => dx.abs() + dy.abs();
// #enddocregion deprecated
