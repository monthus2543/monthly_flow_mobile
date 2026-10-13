const income = 'income';
const expense = 'expense';
const investmentTransfer = 'investment';

class Category {
  final int id;
  final String name;
  final String type;
  final String icon;
  final int sortOrder;
  final bool isActive;
  final int? colorValue;

  const Category(this.id, this.name, this.type, this.icon,
      {this.sortOrder = 0, this.isActive = true, this.colorValue});

  factory Category.fromMap(Map<String, Object?> map) => Category(
        map['id'] as int,
        map['name'] as String,
        map['type'] as String,
        map['icon_key'] as String,
        sortOrder: (map['sort_order'] as int?) ?? 0,
        isActive: ((map['is_active'] as int?) ?? 1) == 1,
        colorValue: map['color_value'] as int?,
      );

  Map<String, Object?> toMap() => {
        'name': name,
        'type': type,
        'icon_key': icon,
        'sort_order': sortOrder,
        'is_active': isActive ? 1 : 0,
        'color_value': colorValue,
      };
}

class Entry {
  final int? id;
  final String title;
  final int amountMinor;
  final String type;
  final int categoryId;
  final DateTime date;
  final String note;
  final int createdAt;
  final int updatedAt;
  final int accountId;
  final String receiptPath;
  final bool isFavorite;

  const Entry(
      {this.id,
      required this.title,
      required this.amountMinor,
      required this.type,
      required this.categoryId,
      required this.date,
      this.note = '',
      required this.createdAt,
      int? updatedAt,
      this.accountId = 1,
      this.receiptPath = '',
      this.isFavorite = false})
      : updatedAt = updatedAt ?? createdAt;

  factory Entry.fromMap(Map<String, Object?> map) => Entry(
        id: map['id'] as int,
        title: map['title'] as String,
        amountMinor: map['amount_minor'] as int,
        type: map['type'] as String,
        categoryId: map['category_id'] as int,
        date: DateTime.parse(map['transaction_date'] as String),
        note: (map['note'] as String?) ?? '',
        createdAt: map['created_at'] as int,
        updatedAt: (map['updated_at'] as int?) ?? map['created_at'] as int,
        accountId: (map['account_id'] as int?) ?? 1,
        receiptPath: (map['receipt_path'] as String?) ?? '',
        isFavorite: ((map['is_favorite'] as int?) ?? 0) == 1,
      );

  Map<String, Object?> toMap() => {
        'title': title,
        'amount_minor': amountMinor,
        'type': type,
        'category_id': categoryId,
        'transaction_date': date.toIso8601String().substring(0, 10),
        'note': note,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'account_id': accountId,
        'receipt_path': receiptPath,
        'is_favorite': isFavorite ? 1 : 0,
      };
}

class Account {
  final int? id;
  final String name;
  final String kind;
  final int openingBalanceMinor;
  final bool isActive;
  const Account(
      {this.id,
      required this.name,
      this.kind = 'cash',
      this.openingBalanceMinor = 0,
      this.isActive = true});
  factory Account.fromMap(Map<String, Object?> map) => Account(
      id: map['id'] as int,
      name: map['name'] as String,
      kind: map['kind'] as String,
      openingBalanceMinor: (map['opening_balance_minor'] as int?) ?? 0,
      isActive: ((map['is_active'] as int?) ?? 1) == 1);
  Map<String, Object?> toMap() => {
        'name': name,
        'kind': kind,
        'opening_balance_minor': openingBalanceMinor,
        'is_active': isActive ? 1 : 0
      };
}

class Budget {
  final int? id;
  final String month;
  final int? categoryId;
  final int amountMinor;
  const Budget(
      {this.id,
      required this.month,
      this.categoryId,
      required this.amountMinor});
  factory Budget.fromMap(Map<String, Object?> map) => Budget(
      id: map['id'] as int,
      month: map['month'] as String,
      categoryId: map['category_id'] as int?,
      amountMinor: map['amount_minor'] as int);
  Map<String, Object?> toMap() =>
      {'month': month, 'category_id': categoryId, 'amount_minor': amountMinor};
}

class RecurringRule {
  final int? id;
  final String title;
  final int amountMinor;
  final String type;
  final int categoryId;
  final int accountId;
  final int dayOfMonth;
  final String note;
  final bool isActive;
  final String lastGeneratedMonth;
  final String startMonth;
  const RecurringRule(
      {this.id,
      required this.title,
      required this.amountMinor,
      required this.type,
      required this.categoryId,
      this.accountId = 1,
      required this.dayOfMonth,
      this.note = '',
      this.isActive = true,
      this.lastGeneratedMonth = '',
      this.startMonth = ''});
  factory RecurringRule.fromMap(Map<String, Object?> map) => RecurringRule(
      id: map['id'] as int,
      title: map['title'] as String,
      amountMinor: map['amount_minor'] as int,
      type: map['type'] as String,
      categoryId: map['category_id'] as int,
      accountId: (map['account_id'] as int?) ?? 1,
      dayOfMonth: map['day_of_month'] as int,
      note: (map['note'] as String?) ?? '',
      isActive: ((map['is_active'] as int?) ?? 1) == 1,
      lastGeneratedMonth: (map['last_generated_month'] as String?) ?? '',
      startMonth: (map['start_month'] as String?) ?? '');
  Map<String, Object?> toMap() => {
        'title': title,
        'amount_minor': amountMinor,
        'type': type,
        'category_id': categoryId,
        'account_id': accountId,
        'day_of_month': dayOfMonth,
        'note': note,
        'is_active': isActive ? 1 : 0,
        'last_generated_month': lastGeneratedMonth,
        'start_month': startMonth
      };
}

class SavingGoal {
  final int? id;
  final String name;
  final int targetMinor;
  final int savedMinor;
  final String dueDate;
  const SavingGoal(
      {this.id,
      required this.name,
      required this.targetMinor,
      this.savedMinor = 0,
      this.dueDate = ''});
  factory SavingGoal.fromMap(Map<String, Object?> map) => SavingGoal(
      id: map['id'] as int,
      name: map['name'] as String,
      targetMinor: map['target_minor'] as int,
      savedMinor: map['saved_minor'] as int,
      dueDate: (map['due_date'] as String?) ?? '');
  Map<String, Object?> toMap() => {
        'name': name,
        'target_minor': targetMinor,
        'saved_minor': savedMinor,
        'due_date': dueDate
      };
}

class BillReminder {
  final int? id;
  final String title;
  final int amountMinor;
  final int dayOfMonth;
  final bool isActive;
  const BillReminder(
      {this.id,
      required this.title,
      this.amountMinor = 0,
      required this.dayOfMonth,
      this.isActive = true});
  factory BillReminder.fromMap(Map<String, Object?> map) => BillReminder(
      id: map['id'] as int,
      title: map['title'] as String,
      amountMinor: map['amount_minor'] as int,
      dayOfMonth: map['day_of_month'] as int,
      isActive: ((map['is_active'] as int?) ?? 1) == 1);
  Map<String, Object?> toMap() => {
        'title': title,
        'amount_minor': amountMinor,
        'day_of_month': dayOfMonth,
        'is_active': isActive ? 1 : 0
      };
}

bool sameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;
int sumType(Iterable<Entry> rows, String type) => rows
    .where((row) => row.type == type)
    .fold(0, (sum, row) => sum + row.amountMinor);

List<Entry> buildMonthlyEntries(
    Entry template, DateTime startMonth, int count) {
  if (count < 1 || count > 120) {
    throw ArgumentError.value(count, 'count');
  }
  return List.generate(count, (index) {
    final month = DateTime(startMonth.year, startMonth.month + index);
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    return Entry(
      title: template.title,
      amountMinor: template.amountMinor,
      type: template.type,
      categoryId: template.categoryId,
      date: DateTime(
          month.year, month.month, template.date.day.clamp(1, lastDay)),
      note: template.note,
      createdAt: template.createdAt + index,
      updatedAt: template.updatedAt + index,
      accountId: template.accountId,
      receiptPath: template.receiptPath,
      isFavorite: template.isFavorite,
    );
  });
}
