import '../currency/app_currency.dart';

/// A manually entered portfolio snapshot, not a cash transfer or a live quote.
class Investment {
  const Investment({
    this.id,
    required this.name,
    required this.investedMinor,
    required this.currentMinor,
    required this.currencyCode,
    required this.valuedAt,
    this.note = '',
  });
  final int? id;
  final String name;
  final int investedMinor;
  final int currentMinor;
  final String currencyCode;
  final DateTime valuedAt;
  final String note;
  int get gainMinor => currentMinor - investedMinor;
  double? get returnPercent =>
      investedMinor == 0 ? null : gainMinor * 100 / investedMinor;
  void validate() {
    if (name.trim().isEmpty ||
        name.length > 100 ||
        investedMinor < 0 ||
        currentMinor < 0 ||
        investedMinor > 99999999999999 ||
        currentMinor > 99999999999999 ||
        !currencySymbols.containsKey(currencyCode) ||
        note.length > 2000)
      throw const FormatException('Invalid investment');
  }

  Map<String, Object?> toMap() => {
    'name': name.trim(),
    'invested_minor': investedMinor,
    'current_minor': currentMinor,
    'currency_code': currencyCode,
    'valued_at': valuedAt.toIso8601String().substring(0, 10),
    'note': note,
  };
  factory Investment.fromMap(Map<String, Object?> m) => Investment(
    id: m['id'] as int?,
    name: m['name'] as String,
    investedMinor: m['invested_minor'] as int,
    currentMinor: m['current_minor'] as int,
    currencyCode: m['currency_code'] as String,
    valuedAt: DateTime.parse(m['valued_at'] as String),
    note: m['note'] as String? ?? '',
  );
}
