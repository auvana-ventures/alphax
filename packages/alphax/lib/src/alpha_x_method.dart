/// HTTP methods supported by the AlphaX 1.0 request contract.
enum HttpMethod {
  /// Retrieves a representation of a resource.
  get('GET'),

  /// Creates or submits a representation.
  post('POST'),

  /// Replaces a representation.
  put('PUT'),

  /// Partially updates a representation.
  patch('PATCH'),

  /// Removes a representation.
  delete('DELETE'),

  /// Retrieves response metadata without a response body.
  head('HEAD'),

  /// Requests communication options for a resource or server.
  options('OPTIONS');

  const HttpMethod(this.value);

  /// Wire-format method token.
  final String value;

  /// Parses a case-insensitive HTTP method token.
  static HttpMethod parse(String value) {
    final normalized = value.trim().toUpperCase();
    for (final method in values) {
      if (method.value == normalized) {
        return method;
      }
    }
    throw FormatException('Unsupported AlphaX HTTP method: $value');
  }

  /// Returns the parsed method or `null` for an unsupported token.
  static HttpMethod? tryParse(String value) {
    try {
      return parse(value);
    } on FormatException {
      return null;
    }
  }

  @override
  String toString() => value;
}
