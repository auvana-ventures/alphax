/// Parses an HTTP-date or an ISO-8601 date into UTC.
DateTime? parseAlphaXHttpDate(String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }

  final iso = DateTime.tryParse(normalized);
  if (iso != null) {
    return iso.toUtc();
  }

  final imfFixdate = RegExp(
    r'^(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun),\s*'
    r'(\d{1,2})\s+'
    r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+'
    r'(\d{4})\s+'
    r'(\d{2}):(\d{2}):(\d{2})\s+GMT$',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (imfFixdate != null) {
    return _utcDate(
      year: int.parse(imfFixdate.group(3)!),
      month: _month(imfFixdate.group(2)!),
      day: int.parse(imfFixdate.group(1)!),
      hour: int.parse(imfFixdate.group(4)!),
      minute: int.parse(imfFixdate.group(5)!),
      second: int.parse(imfFixdate.group(6)!),
    );
  }

  final rfc850 = RegExp(
    r'^(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday),\s*'
    r'(\d{1,2})-(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)-'
    r'(\d{2})\s+'
    r'(\d{2}):(\d{2}):(\d{2})\s+GMT$',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (rfc850 != null) {
    final shortYear = int.parse(rfc850.group(3)!);
    return _utcDate(
      year: shortYear >= 70 ? 1900 + shortYear : 2000 + shortYear,
      month: _month(rfc850.group(2)!),
      day: int.parse(rfc850.group(1)!),
      hour: int.parse(rfc850.group(4)!),
      minute: int.parse(rfc850.group(5)!),
      second: int.parse(rfc850.group(6)!),
    );
  }

  final asctime = RegExp(
    r'^(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun)\s+'
    r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+'
    r'(\d{1,2})\s+'
    r'(\d{2}):(\d{2}):(\d{2})\s+'
    r'(\d{4})$',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (asctime == null) {
    return null;
  }
  return _utcDate(
    year: int.parse(asctime.group(6)!),
    month: _month(asctime.group(1)!),
    day: int.parse(asctime.group(2)!),
    hour: int.parse(asctime.group(3)!),
    minute: int.parse(asctime.group(4)!),
    second: int.parse(asctime.group(5)!),
  );
}

DateTime _utcDate({
  required int year,
  required int month,
  required int day,
  required int hour,
  required int minute,
  required int second,
}) => DateTime.utc(year, month, day, hour, minute, second);

int _month(String value) => const <String, int>{
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
}[value.toLowerCase()]!;
