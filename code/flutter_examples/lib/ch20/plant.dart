// #docregion plant
/// A plant from the catalog API.
class Plant {
  const Plant({
    required this.id,
    required this.name,
    required this.light,
    required this.heightCm,
  });

  final int id;
  final String name;
  final String light;
  final int heightCm;

  /// Strict parsing: every field must be present and of the right type, and
  /// a failure says which fields were found. The map pattern checks all the
  /// types in one place instead of scattering `as` casts.
  factory Plant.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw FormatException(
        'Plant must be a JSON object, got ${json.runtimeType}',
      );
    }
    return switch (json) {
      {
        'id': int id,
        'name': String name,
        'light': String light,
        'heightCm': int heightCm,
      } =>
        Plant(id: id, name: name, light: light, heightCm: heightCm),
      _ => throw FormatException(
        'Plant has missing or wrongly typed fields: ${_describe(json)}',
      ),
    };
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'light': light,
    'heightCm': heightCm,
  };

  static String _describe(Map<String, Object?> json) =>
      json.entries.map((e) => '${e.key}: ${e.value.runtimeType}').join(', ');
}
// #enddocregion plant

// #docregion paged
/// One page of results and where to ask for the next one (null at the end).
class Paged<T> {
  const Paged(this.items, {this.nextPage});
  final List<T> items;
  final int? nextPage;
}
// #enddocregion paged
