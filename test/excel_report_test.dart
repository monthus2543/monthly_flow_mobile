import 'dart:io';
import 'package:excel_plus/excel_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:monthly_flow/export/excel_report.dart';
import 'package:monthly_flow/models/finance_models.dart';

Entry entry(
  String title,
  int amount,
  String type,
  DateTime date, {
  int account = 1,
  int category = 1,
}) => Entry(
  title: title,
  amountMinor: amount,
  type: type,
  categoryId: category,
  accountId: account,
  date: date,
  createdAt: 0,
);
CellIndex at(String cell) => CellIndex.indexByString(cell);
double number(Sheet sheet, String cell) =>
    double.parse(sheet.evaluate(at(cell)).toString());
void main() {
  setUpAll(() => initializeDateFormatting('th'));
  final entries = [
    entry('เงินเดือน', 2400050, income, DateTime(2024, 1, 1)),
    entry('อาหาร', 12345, expense, DateTime(2024, 2, 29)),
    entry('=SUM(A1:A3)', 50, expense, DateTime(2024, 12, 31)),
    entry(
      'Different wallet',
      9900,
      expense,
      DateTime(2024, 1, 1),
      account: 2,
      category: 2,
    ),
    entry('Outside year', 100, expense, DateTime(2023, 1, 1)),
  ];
  ExcelReportData data({bool charts = true, int? account}) => ExcelReportData(
    options: ReportOptions(
      years: [2025, 2024, 2024],
      includeCharts: charts,
      accountId: account,
      selectedMonth: DateTime(2024, 2),
    ),
    entries: entries,
    categoryNames: {1: 'อาหาร', 2: 'เดินทาง'},
    accountNames: {1: 'เงินสด', 2: 'ธนาคาร'},
  );
  test(
    'reference layout round trips real dates and totals with editable cell-linked charts',
    () {
      final bytes = buildExcelReport(data(account: 1));
      final wb = Excel.decodeBytes(bytes);
      expect(wb.tables.keys.toList(), [
        '2567',
        'สรุป 2567',
        'ลงทุน 2567',
        'ข้อมูล 2567',
        '2568',
        'สรุป 2568',
        'ลงทุน 2568',
        'ข้อมูล 2568',
      ]);
      final s = wb['2567'];
      expect(s.cell(at('D1')).value, TextCellValue('รายรับ'));
      expect(s.cell(at('J1')).value, TextCellValue('ค่าใช้จ่าย'));
      expect(s.cell(at('F18')).value, DoubleCellValue(24000.5));
      expect(s.cell(at('J18')).displayText, '29/02/2024');
      expect(number(s, 'Y30'), 24000.5);
      expect(number(s, 'Z30'), 123.95);
      expect(number(s, 'C5'), -123.45);
      expect(s.cell(at('C1')).dataValidation!.formula1, contains('2024-12'));
      expect(s.cell(at('P18')).value, isNull);
      expect(s.charts.length, 1);
      expect(s.charts.first.series.length, 3);
      expect(wb['สรุป 2567'].charts.length, 2);
      expect(
        wb['ข้อมูล 2567'].cell(at('C4')).value,
        TextCellValue('=SUM(A1:A3)'),
      );
      expect(wb['ข้อมูล 2567'].maxColumns, 7);
      expect(number(wb['2568'], 'C5'), 0);
      final dir = Directory('build/export-preview')
        ..createSync(recursive: true);
      File('${dir.path}/MonthlyFlow_reference.xlsx').writeAsBytesSync(bytes);
    },
  );
  test(
    'month selection and manually entered investments update all summaries',
    () {
      final wb = Excel.decodeBytes(
        buildExcelReport(data(account: 1, charts: false)),
      );
      final s = wb['2567'];
      s.updateCell(at('C1'), TextCellValue('2024-01'));
      wb.recalculate();
      expect(number(s, 'C5'), 24000.5);
      expect(wb['สรุป 2567'].evaluate(at('C18')), TextCellValue('เงินเดือน'));
      s.updateCell(at('P18'), DateCellValue(year: 2024, month: 1, day: 12));
      s.updateCell(at('Q18'), TextCellValue('Asset'));
      s.updateCell(at('R18'), DoubleCellValue(1000));
      s.updateCell(at('S18'), TextCellValue('ซื้อ'));
      final inv = wb['ลงทุน 2567'];
      inv.updateCell(at('B5'), TextCellValue('Asset'));
      inv.updateCell(at('D5'), DoubleCellValue(1100));
      wb.recalculate();
      expect(number(s, 'C6'), 1000);
      expect(number(s, 'C5'), 23000.5);
      expect(number(inv, 'E5'), 100);
      expect(number(inv, 'F5'), 0.1);
      expect(number(s, 'AA18'), 1000);
      s.updateCell(at('P19'), DateCellValue(year: 2024, month: 1, day: 15));
      s.updateCell(at('Q19'), TextCellValue('Asset'));
      s.updateCell(at('R19'), DoubleCellValue(200));
      s.updateCell(at('S19'), TextCellValue('ขาย'));
      wb.recalculate();
      expect(number(s, 'C6'), 800);
      expect(number(inv, 'C5'), 800);
      expect(wb['สรุป 2567'].evaluate(at('O19')), TextCellValue('Asset'));
    },
  );
  test(
    'filters, empty years, selected currency, and English retain their meanings',
    () {
      final report = data(charts: false, account: 2);
      final wb = Excel.decodeBytes(buildExcelReport(report));
      expect(report.years.first.expenseMinor, 9900);
      expect(wb['2567'].charts, isEmpty);
      expect(number(wb['2567'], 'Z30'), 99);
      final english = Excel.decodeBytes(
        buildExcelReport(
          ExcelReportData(
            options: ReportOptions(
              years: [2026],
              currencyCode: 'USD',
              language: 'en',
            ),
            entries: [entry('Income', 123456, income, DateTime(2026, 1, 1))],
            categoryNames: {},
            accountNames: {},
          ),
        ),
      );
      expect(
        english['2026'].cell(at('B13')).value.toString(),
        contains('Currency: USD'),
      );
      expect(
        english['Data 2026'].cell(at('F1')).value,
        TextCellValue('Amount (USD)'),
      );
      expect(number(english['2026'], 'Y30'), 1234.56);
    },
  );
  test(
    'large exports retain every transaction without internal IDs or receipt paths',
    () {
      final report = ExcelReportData(
        options: ReportOptions(years: [2026], includeCharts: false),
        entries: List.generate(
          2000,
          (i) => entry('รายการ $i', 101, income, DateTime(2026, 1, 1)),
        ),
        categoryNames: {},
        accountNames: {},
      );
      final wb = Excel.decodeBytes(buildExcelReport(report));
      expect(number(wb['2569'], 'Y30'), closeTo(2020, 0.000001));
      final titles = List.generate(
        2000,
        (i) => wb['ข้อมูล 2569']
            .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1))
            .value
            .toString(),
      );
      expect(titles.toSet(), {for (var i = 0; i < 2000; i++) 'รายการ $i'});
      expect(wb['ข้อมูล 2569'].maxColumns, 7);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
