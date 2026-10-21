import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:http/http.dart' as http;

import 'failure.dart';
import 'plant.dart';

// #docregion parse
/// Parses a list response. Top-level so it can run in another isolate.
List<Plant> parsePlants(String body) {
  final data = jsonDecode(body);
  if (data is! List<Object?>) {
    throw const FormatException('Expected a JSON array');
  }
  return [for (final item in data) Plant.fromJson(item)];
}
// #enddocregion parse

// #docregion api
class PlantApi {
  PlantApi({
    required this.client,
    required this.baseUri,
    this.token,
    this.timeout = const Duration(seconds: 10),
  });

  final http.Client client;
  final Uri baseUri;
  final String? token;
  final Duration timeout;

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<ApiResult<Paged<Plant>>> list({int page = 1}) => _send(
    () => client.get(
      baseUri.replace(path: '/plants', queryParameters: {'page': '$page'}),
      headers: _headers,
    ),
    (response) async {
      // Decode the bytes as UTF-8 ourselves: JSON is defined as UTF-8.
      final body = utf8.decode(response.bodyBytes);
      // Parse in another isolate so a big response cannot freeze the UI.
      final plants = await Isolate.run(() => parsePlants(body));
      final next = int.tryParse(response.headers['x-next-page'] ?? '');
      return Paged(plants, nextPage: next);
    },
  );

  Future<ApiResult<Plant>> create(Plant plant) => _send(
    () => client.post(
      baseUri.replace(path: '/plants'),
      headers: {..._headers, 'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(plant.toJson()),
    ),
    (response) async =>
        Plant.fromJson(jsonDecode(utf8.decode(response.bodyBytes))),
  );

  /// One place for status codes, timeouts and exceptions.
  Future<ApiResult<T>> _send<T>(
    Future<http.Response> Function() request,
    Future<T> Function(http.Response) parse,
  ) async {
    try {
      final response = await request().timeout(timeout);
      switch (response.statusCode) {
        case >= 200 && < 300:
          return ApiOk(await parse(response));
        case 401 || 403:
          return const ApiErr(Unauthorized());
        case 404:
          return const ApiErr(NotFound());
        default:
          return ApiErr(ServerFailure(response.statusCode));
      }
    } on Object catch (e) {
      return ApiErr(classify(e));
    }
  }
}
// #enddocregion api
