import 'dart:typed_data';
import 'package:excel_plus/excel_plus.dart';
import '../models/finance_models.dart';
import '../models/investment.dart';
import '../models/investment_entry.dart';
part 'excel_report_layout.dart';

const excelMimeType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

class ReportOptions {
  ReportOptions({
    required Iterable<int> years,
    this.accountId,
    this.categoryId,
    this.includeCharts = true,
    this.language = 'th',
    this.currencyCode = 'THB',
    this.selectedMonth,
  }) : years = (years.toSet().toList()..sort());
  final List<int> years;
  final int? accountId;
  final int? categoryId;
  final bool includeCharts;
  final String language;
  final String currencyCode;
  final DateTime? selectedMonth;
}

class YearReport {
  YearReport(this.year, this.entries);
  final int year;
  final List<Entry> entries;
  int get incomeMinor => sumType(entries, income);
  int get expenseMinor => sumType(entries, expense);
  int get investmentMinor => sumType(entries, investmentTransfer);
  int get netMinor => incomeMinor - expenseMinor - investmentMinor;
  int monthTotal(int month, String type) =>
      sumType(entries.where((e) => e.date.month == month).toList(), type);
}

class ExcelReportData {
  ExcelReportData({
    this.ownerId,
    required this.options,
    required Iterable<Entry> entries,
    required this.categoryNames,
    required this.accountNames,
    this.investments = const [],
    this.investmentEntries = const [],
  }) : years = options.years
           .map(
             (year) => YearReport(
               year,
               entries
                   .where(
                     (e) =>
                         e.date.year == year &&
                         (e.type != investmentTransfer ||
                             investmentEntries
                                 .where((v) => v.id != null && -v.id! == e.id)
                                 .every(
                                   (v) => investments.any(
                                     (f) =>
                                         f.id == v.fundId &&
                                         f.currencyCode == options.currencyCode,
                                   ),
                                 )) &&
                         (options.accountId == null ||
                             e.accountId == options.accountId) &&
                         (options.categoryId == null ||
                             e.categoryId == options.categoryId),
                   )
                   .toList()
                 ..sort((a, b) => a.date.compareTo(b.date)),
             ),
           )
           .toList();
  final ReportOptions options;
  final String? ownerId;
  final List<YearReport> years;
  final Map<int, String> categoryNames;
  final Map<int, String> accountNames;
  final List<Investment> investments;
  final List<InvestmentEntry> investmentEntries;
  int get fundCount =>
      investments.where((f) => f.currencyCode == options.currencyCode).length;
  DateTime get investmentMonth {
    final month = options.selectedMonth;
    return month != null && options.years.contains(month.year)
        ? DateTime(month.year, month.month)
        : DateTime(options.years.last, month?.month ?? 1);
  }

  int investedInMonth(DateTime month) {
    if (options.categoryId != null && options.categoryId != -1) return 0;
    final funds = investments
        .where((f) => f.currencyCode == options.currencyCode)
        .map((f) => f.id)
        .toSet();
    return investmentEntries
        .where(
          (e) =>
              funds.contains(e.fundId) &&
              sameMonth(e.date, month) &&
              (options.accountId == null || e.accountId == options.accountId),
        )
        .fold<int>(0, (sum, e) => sum + e.amountMinor);
  }
}

/// /// Builds the same reference layout as the web report.
Uint8List buildExcelReport(ExcelReportData data) =>
    buildReferenceExcelReport(data);
