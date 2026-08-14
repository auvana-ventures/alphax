/// Immutable, case-insensitive HTTP headers with multi-value support.
final class AlphaXHeaders {
  /// Creates an empty header collection.
  const AlphaXHeaders.empty() : _values = const <String, List<String>>{};

  const AlphaXHeaders._(this._values);

  /// Creates headers from one value per name.
  factory AlphaXHeaders([Map<String, String> values = const <String, String>{}]) =>
      AlphaXHeaders.fromEntries(values.entries);

  /// Creates headers from entries, retaining repeated names as multiple values.
  factory AlphaXHeaders.fromEntries(Iterable<MapEntry<String, String>> entries) {
    final normalized = <String, List<String>>{};
    for (final entry in entries) {
      final name = _normalizeName(entry.key);
      if (entry.value.contains('\r') || entry.value.contains('\n')) {
        throw ArgumentError.value(
          entry.value,
          entry.key,
          'Header values cannot contain newlines',
        );
      }
      normalized.putIfAbsent(name, () => <String>[]).add(entry.value);
    }

    return AlphaXHeaders._(
      Map<String, List<String>>.unmodifiable({
        for (final entry in normalized.entries) entry.key: List<String>.unmodifiable(entry.value),
      }),
    );
  }

  final Map<String, List<String>> _values;

  /// Header names in normalized lowercase form.
  Iterable<String> get names => _values.keys;

  /// Header entries with one entry for each value.
  Iterable<MapEntry<String, String>> get entries sync* {
    for (final entry in _values.entries) {
      for (final value in entry.value) {
        yield MapEntry<String, String>(entry.key, value);
      }
    }
  }

  /// Whether [name] is present, ignoring case.
  bool contains(String name) => _values.containsKey(_normalizeName(name));

  /// Returns all values for [name], ignoring case.
  List<String> values(String name) => _values[_normalizeName(name)] ?? const <String>[];

  /// Returns repeated values joined using ordinary HTTP comma semantics.
  String? operator [](String name) {
    final headerValues = values(name);
    return headerValues.isEmpty ? null : headerValues.join(', ');
  }

  /// Returns a normalized single-value map.
  Map<String, String> toMap() => Map<String, String>.unmodifiable({
    for (final name in names) name: this[name]!,
  });

  /// Returns a new collection with [value] appended to [name].
  AlphaXHeaders add(String name, String value) => AlphaXHeaders.fromEntries(
    <MapEntry<String, String>>[...entries, MapEntry<String, String>(name, value)],
  );

  /// Returns a new collection with all values for [name] replaced by [value].
  AlphaXHeaders set(String name, String value) {
    final normalizedName = _normalizeName(name);
    return AlphaXHeaders.fromEntries(<MapEntry<String, String>>[
      ...entries.where((entry) => entry.key != normalizedName),
      MapEntry<String, String>(normalizedName, value),
    ]);
  }

  /// Returns a new collection without [name].
  AlphaXHeaders remove(String name) {
    final normalizedName = _normalizeName(name);
    return AlphaXHeaders.fromEntries(entries.where((entry) => entry.key != normalizedName));
  }

  static String _normalizeName(String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty || normalized.contains(RegExp(r'[\s:]'))) {
      throw ArgumentError.value(name, 'name', 'Header names must be non-empty tokens');
    }
    return normalized;
  }
}
