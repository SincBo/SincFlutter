Map<String, dynamic> mapFromDynamic(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

String _toSnakeCase(String key) {
  // Convert camelCase or PascalCase to snake_case
  final buffer = StringBuffer();
  for (var i = 0; i < key.length; i++) {
    final char = key[i];
    if (char.toUpperCase() == char && i > 0 && key[i - 1] != '_') {
      buffer.write('_');
    }
    buffer.write(char.toLowerCase());
  }
  return buffer.toString();
}

Map<String, dynamic> normalizeKeys(Map<String, dynamic> map) {
  final out = <String, dynamic>{};
  for (final entry in map.entries) {
    out[entry.key] = entry.value;
    final sn = _toSnakeCase(entry.key);
    if (sn != entry.key) {
      out.putIfAbsent(sn, () => entry.value);
    }
  }
  return out;
}

String getStringFromMap(Map<String, dynamic> map, List<String> candidates) {
  for (final key in candidates) {
    final v = map[key];
    if (v is String && v.isNotEmpty) return v;
  }
  // try normalized forms
  for (final key in candidates) {
    final sn = _toSnakeCase(key);
    final v = map[sn];
    if (v is String && v.isNotEmpty) return v;
  }
  return '';
}
