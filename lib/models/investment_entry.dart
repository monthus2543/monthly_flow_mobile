class InvestmentEntry {
  final int? id;
  final int? accountId;
  final bool contributionOnly;
  final int fundId, amountMinor, currentMinor;
  final DateTime date;
  final int createdAt;
  final String note;
  const InvestmentEntry({
    this.id,
    this.accountId,
    this.contributionOnly = false,
    required this.fundId,
    required this.amountMinor,
    required this.currentMinor,
    required this.date,
    required this.createdAt,
    this.note = '',
  });
  void validate() {
    if ((accountId != null && accountId! <= 0) ||
        fundId <= 0 ||
        amountMinor <= 0 ||
        amountMinor > 99999999999999 ||
        currentMinor < 0 ||
        currentMinor > 99999999999999 ||
        note.length > 2000 ||
        createdAt < 0) {
      throw const FormatException('Invalid investment entry');
    }
  }

  Map<String, Object?> toMap() => {
    'fund_id': fundId,
    if (accountId != null) 'account_id': accountId,
    if (contributionOnly) 'contribution_only': 1,
    'amount_minor': amountMinor,
    'current_minor': currentMinor,
    'transaction_date':
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    'created_at': createdAt,
    'note': note.trim(),
  };
  factory InvestmentEntry.fromMap(Map<String, Object?> row) => InvestmentEntry(
    id: row['id'] as int?,
    accountId: row['account_id'] as int?,
    contributionOnly: row['contribution_only'] == 1,
    fundId: row['fund_id'] as int,
    amountMinor: row['amount_minor'] as int,
    currentMinor: row['current_minor'] as int,
    date: DateTime.parse(row['transaction_date'] as String),
    createdAt: row['created_at'] as int,
    note: row['note'] as String? ?? '',
  );
}
