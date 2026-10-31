/// Small typed helpers for reading content JSON with clear error messages.
library;

/// Thrown when a content file does not match the expected structure.
class ContentFormatException implements Exception {
  ContentFormatException(this.message);

  final String message;

  @override
  String toString() => 'ContentFormatException: $message';
}

/// A decoded JSON object.
typedef JsonMap = Map<String, Object?>;

JsonMap asMap(Object? value, String ctx) {
  if (value is Map) return value.cast<String, Object?>();
  throw ContentFormatException('$ctx: expected an object');
}

List<Object?> asList(Object? value, String ctx) {
  if (value is List) return value.cast<Object?>();
  throw ContentFormatException('$ctx: expected a list');
}

String reqString(JsonMap m, String key, String ctx) {
  final v = m[key];
  if (v is String && v.isNotEmpty) return v;
  throw ContentFormatException('$ctx: missing or empty string "$key"');
}

String? optString(JsonMap m, String key, String ctx) {
  final v = m[key];
  if (v == null) return null;
  if (v is String) return v;
  throw ContentFormatException('$ctx: "$key" must be a string');
}

int reqInt(JsonMap m, String key, String ctx) {
  final v = m[key];
  if (v is int) return v;
  throw ContentFormatException('$ctx: missing or invalid integer "$key"');
}

int optInt(JsonMap m, String key, String ctx, {int fallback = 0}) {
  final v = m[key];
  if (v == null) return fallback;
  if (v is int) return v;
  throw ContentFormatException('$ctx: "$key" must be an integer');
}

double reqDouble(JsonMap m, String key, String ctx) {
  final v = m[key];
  if (v is num) return v.toDouble();
  throw ContentFormatException('$ctx: missing or invalid number "$key"');
}

bool optBool(JsonMap m, String key, String ctx, {bool fallback = false}) {
  final v = m[key];
  if (v == null) return fallback;
  if (v is bool) return v;
  throw ContentFormatException('$ctx: "$key" must be true or false');
}

List<JsonMap> objectList(
  JsonMap m,
  String key,
  String ctx, {
  bool required = true,
}) {
  final v = m[key];
  if (v == null) {
    if (required) throw ContentFormatException('$ctx: missing list "$key"');
    return const [];
  }
  final list = asList(v, '$ctx.$key');
  return [
    for (var i = 0; i < list.length; i++) asMap(list[i], '$ctx.$key[$i]'),
  ];
}

List<String> stringList(
  JsonMap m,
  String key,
  String ctx, {
  bool required = false,
}) {
  final v = m[key];
  if (v == null) {
    if (required) throw ContentFormatException('$ctx: missing list "$key"');
    return const [];
  }
  final list = asList(v, '$ctx.$key');
  return [
    for (var i = 0; i < list.length; i++)
      list[i] is String
          ? list[i] as String
          : throw ContentFormatException('$ctx.$key[$i]: expected a string'),
  ];
}
