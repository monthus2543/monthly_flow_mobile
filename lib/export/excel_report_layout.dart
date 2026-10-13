part of 'excel_report.dart';

/// Side-by-side income/expenses with editable investment inputs, matching web.
Uint8List buildReferenceExcelReport(ExcelReportData data) {
  if (data.years.isEmpty) throw ArgumentError('Select at least one year');
  final th = data.options.language == 'th';
  String t(String thai, String english) => th ? thai : english;
  const thaiMonths = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];
  const englishMonths = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  const money = '#,##0.00;[Red]-#,##0.00';
  const green = '#D9EAD3',
      red = '#F4CCCC',
      purple = '#D9D2E9',
      yellow = '#FFF2CC';
  final wb = Excel.createExcel();
  CellIndex at(String a) => CellIndex.indexByString(a);
  TextCellValue text(String s) => TextCellValue(s);
  void cell(
    Sheet s,
    String address,
    CellValue? value, {
    String? fill,
    bool bold = false,
    String? format,
    bool wrap = false,
    int size = 10,
    HorizontalAlign? align,
  }) {
    s.updateCell(
      at(address),
      value,
      cellStyle: CellStyle(
        fontFamily: 'Prompt',
        fontSize: size,
        bold: bold,
        horizontalAlign:
            align ??
            (format == money || format == '0.00%' || value is IntCellValue
                ? HorizontalAlign.Right
                : HorizontalAlign.Left),
        verticalAlign: VerticalAlign.Center,
        fontColorHex: ExcelColor.fromHexString('#123C39'),
        backgroundColorHex: fill == null
            ? ExcelColor.none
            : ExcelColor.fromHexString(fill),
        textWrapping: wrap ? TextWrapping.WrapText : TextWrapping.Clip,
        numberFormat: format == null
            ? NumFormat.custom(formatCode: 'General')
            : NumFormat.custom(formatCode: format),
      ),
    );
  }

  void f(Sheet s, String a, String formula, {String? format}) =>
      cell(s, a, FormulaCellValue(formula), format: format);
  Sheet base(String name, List<double> widths) {
    final s = wb[name];
    s.showGridLines = false;
    s.zoom = 85;
    for (var i = 0; i < widths.length; i++) s.setColumnWidth(i, widths[i]);
    return s;
  }

  void band(Sheet s, String first, String last, String title, String color) {
    cell(
      s,
      first,
      text(title),
      fill: color,
      bold: true,
      size: 14,
      align: HorizontalAlign.Center,
    );
    s.merge(at(first), at(last));
    s.setRowHeight(at(first).rowIndex, 30);
  }

  void headers(Sheet s, int row, int column, List<String> names) {
    for (var i = 0; i < names.length; i++)
      cell(
        s,
        CellIndex.indexByColumnRow(
          columnIndex: column + i,
          rowIndex: row - 1,
        ).cellId,
        text(names[i]),
        fill: yellow,
        bold: true,
        wrap: true,
        align: HorizontalAlign.Center,
      );
    s.setRowHeight(row - 1, 32);
  }

  String key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
  DateCellValue date(DateTime d) =>
      DateCellValue(year: d.year, month: d.month, day: d.day);
  for (final y in data.years) {
    final yearName = '${th ? y.year + 543 : y.year}';
    final s = base(yearName, [
      3,
      21,
      19,
      15,
      27,
      19,
      23,
      15,
      3,
      15,
      27,
      19,
      23,
      15,
      3,
      15,
      27,
      19,
      14,
      23,
      15,
      3,
      9,
      18,
      19,
      19,
      19,
      16,
    ]);
    if (y == data.years.first) {
      wb.delete('Sheet1');
      wb.setDefaultSheet(yearName);
    }
    s.freezePanes(rows: 17, columns: 3);
    final q = "'$yearName'";
    final incoming = y.entries.where((e) => e.type == income).toList(),
        outgoing = y.entries.where((e) => e.type == expense).toList(),
        deposits = y.entries
            .where((e) => e.type == investmentTransfer)
            .toList();
    final end = [
      117,
      17 + incoming.length,
      17 + outgoing.length,
      17 + deposits.length,
    ].reduce((a, b) => a > b ? a : b);
    String range(String c) => '\$$c\$18:\$$c\$$end';
    final selected = data.options.selectedMonth?.year == y.year
        ? key(data.options.selectedMonth!)
        : y.entries.isEmpty
        ? '${y.year}-01'
        : key(y.entries.last.date);
    final periods = List.generate(
      12,
      (i) => '${y.year}-${(i + 1).toString().padLeft(2, '0')}',
    );
    band(s, 'D1', 'H1', t('รายรับ', 'Income'), green);
    band(s, 'J1', 'N1', t('ค่าใช้จ่าย', 'Expenses'), red);
    band(
      s,
      'P1',
      'U1',
      t('การเก็บออม + ลงทุน', 'Savings + investments'),
      purple,
    );
    band(s, 'W1', 'AB1', '${t('สรุปปี', 'Annual summary')} $yearName', green);
    cell(s, 'B1', text(t('เลือกเดือน', 'Select month')));
    cell(s, 'C1', text(selected), fill: yellow);
    s.setDataValidation(
      at('C1'),
      DataValidation.list(periods, allowBlank: false),
    );
    cell(s, 'E3', text(t('รายรับประจำเดือน', 'Monthly income')));
    f(s, 'F3', 'SUMIFS(${range('F')},${range('H')},\$C\$1)', format: money);
    cell(s, 'K3', text(t('รายจ่ายประจำเดือน', 'Monthly expenses')));
    f(s, 'L3', 'SUMIFS(${range('L')},${range('N')},\$C\$1)', format: money);
    cell(
      s,
      'Q3',
      text(t('เงินลงทุนเดือนนี้', 'Investment this month')),
      wrap: true,
    );
    s.merge(at('Q3'), at('Q4'));
    String net({String? period, String? title}) {
      final filter = period == null ? '' : ',${q}!${range('U')},$period';
      final asset = title == null ? '' : ',${q}!${range('Q')},$title';
      return 'SUMIFS(${q}!${range('R')},${q}!${range('S')},"${t('ซื้อ', 'Buy')}"$filter$asset)-SUMIFS(${q}!${range('R')},${q}!${range('S')},"${t('ขาย', 'Sell')}"$filter$asset)';
    }

    f(s, 'R3', net(period: '\$C\$1'), format: money);
    cell(s, 'B7', text(t('จำนวนกองทุน', 'Number of funds')));
    cell(s, 'C7', IntCellValue(data.fundCount));
    for (final item in [
      (3, t('รายรับรวม', 'Income'), 'F3'),
      (4, t('รายจ่ายรวม', 'Expenses'), 'L3'),
      (5, t('คงเหลือ', 'Balance'), 'C3-C4-C6'),
      (6, t('เงินลงทุนเดือนนี้', 'Investment this month'), 'R3'),
      (9, t('รายรับทั้งปี', 'Annual income'), 'Y30'),
      (10, t('รายจ่ายทั้งปี', 'Annual expenses'), 'Z30'),
      (11, t('เงินเก็บทั้งปี', 'Annual savings'), 'Y30-Z30-AA30'),
    ]) {
      cell(s, 'B${item.$1}', text(item.$2));
      f(s, 'C${item.$1}', item.$3, format: money);
    }
    cell(
      s,
      'B13',
      text(
        '${t('หน่วย', 'Currency')}: ${data.options.currencyCode}\nMonthly Flow\n${t('เปลี่ยน C1 เพื่อดูสรุปเดือน', 'Change C1 to select a month')}',
      ),
      wrap: true,
    );
    s.merge(at('B13'), at('C15'));
    cell(
      s,
      'P6',
      text(
        t(
          'กรอกการลงทุนเอง: วันที่ / รายการ / จำนวนเงิน / ซื้อหรือขาย / กลุ่ม',
          'Enter investments: date / title / amount / buy or sell / group',
        ),
      ),
    );
    s.merge(at('P6'), at('U6'));
    final standard = [
      t('วันที่', 'Date'),
      t('ชื่อรายการ', 'Title'),
      t('จำนวนเงิน', 'Amount'),
      t('กลุ่ม', 'Group'),
      'Year-Month',
    ];
    final investment = [
      ...standard.take(3),
      t('ซื้อ/ขาย', 'Buy/Sell'),
      standard[3],
      standard[4],
    ];
    headers(s, 17, 3, standard);
    headers(s, 17, 9, standard);
    headers(s, 17, 15, investment);
    headers(s, 17, 22, [
      t('ลำดับ', 'No.'),
      t('เดือน', 'Month'),
      t('รายรับ', 'Income'),
      t('รายจ่าย', 'Expenses'),
      t('ออม/ลงทุนสุทธิ', 'Net investments'),
      t('% ลงทุนสุทธิ', 'Investment %'),
    ]);
    void transactions(
      List<Entry> entries,
      int start,
      String helper,
      String monthCol,
    ) {
      for (var r = 18; r <= end; r++) {
        if (r - 18 < entries.length) {
          final e = entries[r - 18];
          final values = <CellValue>[
            date(e.date),
            text(e.title),
            DoubleCellValue(e.amountMinor / 100),
            text(data.categoryNames[e.categoryId] ?? t('อื่น ๆ', 'Other')),
            text(key(e.date)),
          ];
          for (var i = 0; i < values.length; i++)
            cell(
              s,
              CellIndex.indexByColumnRow(
                columnIndex: start + i,
                rowIndex: r - 1,
              ).cellId,
              values[i],
              format: i == 0
                  ? 'dd/mm/yy'
                  : i == 2
                  ? money
                  : null,
            );
        }
        f(
          s,
          '$helper$r',
          'IF($monthCol$r=\$C\$1,COUNTIFS(\$$monthCol\$18:$monthCol$r,\$C\$1),"")',
        );
      }
    }

    transactions(incoming, 3, 'AD', 'H');
    transactions(outgoing, 9, 'AE', 'N');
    for (var r = 18; r <= end; r++) {
      for (final c in ['P', 'Q', 'R', 'S', 'T'])
        cell(
          s,
          '$c$r',
          null,
          fill: '#F5F0FA',
          format: c == 'P'
              ? 'dd/mm/yy'
              : c == 'R'
              ? money
              : null,
        );
      f(s, 'U$r', 'IF(P$r="","",TEXT(P$r,"yyyy-mm"))');
      f(s, 'AF$r', 'IF(U$r=\$C\$1,COUNTIFS(\$U\$18:U$r,\$C\$1),"")');
    }
    for (var i = 0; i < deposits.length; i++) {
      final deposit = deposits[i], r = i + 18;
      cell(s, 'P$r', date(deposit.date), format: 'dd/mm/yy');
      cell(s, 'Q$r', text(deposit.title));
      cell(s, 'R$r', DoubleCellValue(deposit.amountMinor / 100), format: money);
      cell(s, 'S$r', text(t('ซื้อ', 'Buy')));
      cell(s, 'T$r', text(t('ลงทุน', 'Investment')));
    }
    s.setDataValidation(
      at('S18'),
      DataValidation.list([t('ซื้อ', 'Buy'), t('ขาย', 'Sell')]),
      end: at('S$end'),
    );
    for (final c in [29, 30, 31]) s.setColumnHidden(c, true);
    for (var i = 0; i < 12; i++) {
      final r = i + 18;
      cell(s, 'W$r', IntCellValue(i + 1), format: '00');
      cell(s, 'X$r', text((th ? thaiMonths : englishMonths)[i]));
      f(
        s,
        'Y$r',
        'SUMIFS(${range('F')},${range('H')},"${periods[i]}")',
        format: money,
      );
      f(
        s,
        'Z$r',
        'SUMIFS(${range('L')},${range('N')},"${periods[i]}")',
        format: money,
      );
      f(s, 'AA$r', net(period: '"${periods[i]}"'), format: money);
      f(s, 'AB$r', 'IF(Y$r=0,0,AA$r/Y$r)', format: '0.00%');
    }
    cell(s, 'X30', text(t('รวมทั้งปี', 'Annual total')));
    for (final c in ['Y', 'Z', 'AA'])
      f(s, '${c}30', 'SUM(${c}18:${c}29)', format: money);
    f(s, 'AB30', 'IF(Y30=0,0,AA30/Y30)', format: '0.00%');
    if (data.options.includeCharts)
      s.addChart(
        Chart.column(
          anchor: at('W4'),
          anchorTo: at('AC16'),
          title: t(
            'รายรับ / รายจ่าย / ออมและลงทุน',
            'Income / expenses / investments',
          ),
          categories: 'X18:X29',
          legend: LegendPosition.bottom,
          series: [
            for (final spec in [
              ('Y', t('รายรับ', 'Income'), '#008E7B'),
              ('Z', t('รายจ่าย', 'Expenses'), '#D74A40'),
              ('AA', t('ออม/ลงทุนสุทธิ', 'Net investments'), '#9675C9'),
            ])
              ChartSeries(
                name: spec.$2,
                values: '${spec.$1}18:${spec.$1}29',
                style: ChartSeriesStyle(
                  fill: ExcelColor.fromHexString(spec.$3.replaceFirst('#', '')),
                ),
              ),
          ],
        ),
      );
    final monthly = base('${t('สรุป', 'Monthly')} $yearName', [
      3,
      15,
      27,
      19,
      23,
      15,
      3,
      15,
      27,
      19,
      23,
      15,
      3,
      15,
      27,
      19,
      14,
      23,
      15,
    ]);
    band(
      monthly,
      'B1',
      'F1',
      t('ข้อมูลรายรับเดือนที่เลือก', 'Selected month income'),
      green,
    );
    band(
      monthly,
      'H1',
      'L1',
      t('ข้อมูลค่าใช้จ่ายเดือนที่เลือก', 'Selected month expenses'),
      red,
    );
    band(
      monthly,
      'N1',
      'S1',
      t('ข้อมูลการลงทุนเดือนที่เลือก', 'Selected month investments'),
      purple,
    );
    cell(monthly, 'B2', text(t('เดือน', 'Month')));
    f(monthly, 'C2', '$q!C1');
    cell(
      monthly,
      'H2',
      text(
        '${t('เปลี่ยนเดือนในชีต', 'Change month in')} $yearName C1 · ${data.options.currencyCode}',
      ),
    );
    monthly.merge(at('H2'), at('S2'));
    final panels = [
      (1, ['D', 'E', 'F', 'G', 'H'], 'AD', incoming),
      (7, ['J', 'K', 'L', 'M', 'N'], 'AE', outgoing),
      (13, ['P', 'Q', 'R', 'S', 'T', 'U'], 'AF', <Entry>[]),
    ];
    for (final panel in panels) {
      headers(
        monthly,
        17,
        panel.$1,
        panel.$2.length == 5 ? standard : investment,
      );
      cell(
        monthly,
        CellIndex.indexByColumnRow(
          columnIndex: panel.$1 + 1,
          rowIndex: 3,
        ).cellId,
        text(t('รวมประจำเดือน', 'Monthly total')),
      );
      f(
        monthly,
        CellIndex.indexByColumnRow(
          columnIndex: panel.$1 + 2,
          rowIndex: 3,
        ).cellId,
        '$q!${panel.$1 == 1
            ? 'F3'
            : panel.$1 == 7
            ? 'L3'
            : 'R3'}',
        format: money,
      );
      for (var r = 18; r <= end; r++)
        for (var i = 0; i < panel.$2.length; i++)
          f(
            monthly,
            CellIndex.indexByColumnRow(
              columnIndex: panel.$1 + i,
              rowIndex: r - 1,
            ).cellId,
            'IFERROR(INDEX($q!${range(panel.$2[i])},MATCH(${r - 17},$q!${range(panel.$3)},0)),"")',
            format: i == 0
                ? 'dd/mm/yy'
                : i == 2
                ? money
                : null,
          );
      final categoryIds = panel.$4
          .map((e) => data.categoryNames[e.categoryId] ?? t('อื่น ๆ', 'Other'))
          .toSet()
          .toList();
      for (var i = 0; i < categoryIds.length; i++) {
        final r = end + 4 + i;
        final labelCell = CellIndex.indexByColumnRow(
          columnIndex: panel.$1,
          rowIndex: r - 1,
        ).cellId;
        cell(monthly, labelCell, text(categoryIds[i]));
        f(
          monthly,
          CellIndex.indexByColumnRow(
            columnIndex: panel.$1 + 1,
            rowIndex: r - 1,
          ).cellId,
          'SUMIFS($q!${range(panel.$2[2])},$q!${range(panel.$2[3])},$labelCell,$q!${range(panel.$2[4])},$q!\$C\$1)',
          format: money,
        );
      }
      if (data.options.includeCharts && categoryIds.isNotEmpty) {
        final c = panel.$1 == 1 ? 'B' : 'H', v = panel.$1 == 1 ? 'C' : 'I';
        monthly.addChart(
          Chart.column(
            anchor: at('${c}6'),
            anchorTo: at('${panel.$1 == 1 ? 'G' : 'M'}16'),
            title: panel.$1 == 1
                ? t('รายรับตามกลุ่ม', 'Income by group')
                : t('รายจ่ายตามกลุ่ม', 'Expenses by group'),
            categories: '$c${end + 4}:$c${end + 3 + categoryIds.length}',
            legend: LegendPosition.bottom,
            series: [
              ChartSeries(
                name: t('จำนวนเงิน', 'Amount'),
                values: '$v${end + 4}:$v${end + 3 + categoryIds.length}',
                style: ChartSeriesStyle(
                  fill: ExcelColor.fromHexString(
                    panel.$1 == 1 ? '008E7B' : 'D74A40',
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
    monthly.freezePanes(rows: 17);
    final portfolio = base('${t('ลงทุน', 'Investments')} $yearName', [
      3,
      28,
      22,
      22,
      22,
      20,
    ]);
    band(
      portfolio,
      'B1',
      'F1',
      t('สรุปข้อมูลการออม + ลงทุน', 'Savings + investment summary'),
      purple,
    );
    cell(
      portfolio,
      'B2',
      text(
        '${t('กรอกชื่อสินทรัพย์และมูลค่าปัจจุบัน รายการซื้อ/ขายกรอกในชีต', 'Enter asset names and current values. Enter buys/sells in')} $yearName P:T · ${data.options.currencyCode}',
      ),
      wrap: true,
    );
    portfolio.merge(at('B2'), at('F2'));
    portfolio.setRowHeight(1, 40);
    headers(portfolio, 4, 1, [
      t('ชื่อรายการ (กรอกเอง)', 'Asset (input)'),
      t('เงินลงทุนสุทธิ', 'Net invested'),
      t('มูลค่าปัจจุบัน (กรอกเอง)', 'Current value (input)'),
      t('กำไร / ขาดทุน', 'Gain / loss'),
      t('เติบโต / ติดลบ %', 'Return %'),
    ]);
    for (var r = 5; r <= 36; r++) {
      cell(portfolio, 'B$r', null, fill: '#F5F0FA');
      cell(portfolio, 'D$r', null, fill: '#F5F0FA', format: money);
      f(portfolio, 'C$r', 'IF(B$r="","",${net(title: 'B$r')})', format: money);
      f(portfolio, 'E$r', 'IF(OR(B$r="",D$r=""),"",D$r-C$r)', format: money);
      f(
        portfolio,
        'F$r',
        'IF(OR(B$r="",D$r="",C$r=0),"",E$r/C$r)',
        format: '0.00%',
      );
    }
    cell(portfolio, 'B38', text(t('รวมเงินลงทุนสุทธิ', 'Total net invested')));
    f(portfolio, 'C38', net(), format: money);
    final raw = base('${t('ข้อมูล', 'Data')} $yearName', [
      16,
      14,
      28,
      24,
      24,
      20,
      35,
    ]);
    headers(raw, 1, 0, [
      t('วันที่', 'Date'),
      t('ประเภท', 'Type'),
      t('รายการ', 'Title'),
      t('หมวดหมู่', 'Category'),
      t('บัญชี', 'Account'),
      '${t('จำนวนเงิน', 'Amount')} (${data.options.currencyCode})',
      t('หมายเหตุ', 'Note'),
    ]);
    for (var i = 0; i < y.entries.length; i++) {
      final e = y.entries[i];
      final values = <CellValue?>[
        date(e.date),
        text(
          e.type == investmentTransfer
              ? t('ลงทุน', 'Investment')
              : e.type == income
              ? t('รายรับ', 'Income')
              : t('รายจ่าย', 'Expenses'),
        ),
        text(e.title),
        text(data.categoryNames[e.categoryId] ?? t('อื่น ๆ', 'Other')),
        text(data.accountNames[e.accountId] ?? t('ไม่ระบุ', 'Unknown')),
        DoubleCellValue(e.amountMinor / 100),
        e.note.isEmpty ? null : text(e.note),
      ];
      for (var c = 0; c < values.length; c++)
        cell(
          raw,
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: i + 1).cellId,
          values[c],
          format: c == 0
              ? 'dd/mm/yy'
              : c == 5
              ? money
              : null,
        );
    }
    raw.freezePanes(rows: 1);
    raw.setAutoFilter(at('A1'), at('G${y.entries.length + 1}'));
  }
  if (data.investments.isNotEmpty) {
    final sheet = base(t('พอร์ตกรอกเอง', 'Manual portfolios'), [
      28,
      14,
      22,
      22,
      22,
      18,
      18,
      35,
    ]);
    headers(sheet, 1, 0, [
      t('ชื่อพอร์ต', 'Portfolio'),
      t('สกุลเงิน', 'Currency'),
      t('เงินลงทุนสะสม', 'Net invested'),
      t('มูลค่าปัจจุบัน', 'Current value'),
      t('กำไร / ขาดทุน', 'Gain / loss'),
      t('ผลตอบแทน %', 'Return %'),
      t('วันที่ประเมิน', 'Valuation date'),
      t('หมายเหตุ', 'Note'),
    ]);
    final items = data.investments
        .where((v) => data.options.years.contains(v.valuedAt.year))
        .toList();
    for (var i = 0; i < items.length; i++) {
      final value = items[i], r = i + 2;
      cell(sheet, 'A$r', text(value.name));
      cell(sheet, 'B$r', text(value.currencyCode));
      cell(
        sheet,
        'C$r',
        DoubleCellValue(value.investedMinor / 100),
        format: money,
      );
      cell(
        sheet,
        'D$r',
        DoubleCellValue(value.currentMinor / 100),
        format: money,
      );
      f(sheet, 'E$r', 'D$r-C$r', format: money);
      f(sheet, 'F$r', 'IF(C$r=0,"",E$r/C$r)', format: '0.00%');
      cell(sheet, 'G$r', date(value.valuedAt), format: 'dd/mm/yy');
      cell(sheet, 'H$r', value.note.isEmpty ? null : text(value.note));
    }
    sheet.freezePanes(rows: 1);
    sheet.setAutoFilter(at('A1'), at('H${items.length + 1}'));
  }
  if (data.investmentEntries.isNotEmpty) {
    final sheet = base(t('รายการลงทุน', 'Investment entries'), [
      18,
      28,
      14,
      22,
      22,
      35,
    ]);
    headers(sheet, 1, 0, [
      t('วันที่', 'Date'),
      t('กองทุน', 'Fund'),
      t('สกุลเงิน', 'Currency'),
      t('เงินลงทุนเพิ่ม', 'Contribution'),
      t('บัญชีที่ใช้ลงทุน', 'Funding account'),
      t('หมายเหตุ', 'Note'),
    ]);
    final funds = {for (final fund in data.investments) fund.id: fund};
    final entries =
        data.investmentEntries
            .where(
              (e) =>
                  data.options.years.contains(e.date.year) &&
                  funds.containsKey(e.fundId) &&
                  funds[e.fundId]!.currencyCode == data.options.currencyCode &&
                  (data.options.accountId == null ||
                      e.accountId == data.options.accountId) &&
                  (data.options.categoryId == null ||
                      data.options.categoryId == -1),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i], fund = funds[entry.fundId]!, r = i + 2;
      cell(sheet, 'A$r', date(entry.date), format: 'dd/mm/yy');
      cell(sheet, 'B$r', text(fund.name));
      cell(sheet, 'C$r', text(fund.currencyCode));
      cell(
        sheet,
        'D$r',
        DoubleCellValue(entry.amountMinor / 100),
        format: money,
        fill: yellow,
      );
      cell(
        sheet,
        'E$r',
        text(data.accountNames[entry.accountId] ?? t('ไม่ระบุ', 'Unknown')),
      );
      cell(sheet, 'F$r', entry.note.isEmpty ? null : text(entry.note));
    }
    sheet.freezePanes(rows: 1);
    sheet.setAutoFilter(at('A1'), at('F${entries.length + 1}'));
  }
  final investmentSummary = base(t('สรุปลงทุน', 'Investment summary'), [
    24,
    22,
    26,
    16,
  ]);
  cell(
    investmentSummary,
    'A1',
    text(t('เดือนที่เลือก', 'Selected month')),
    bold: true,
  );
  cell(
    investmentSummary,
    'B1',
    date(data.investmentMonth),
    format: 'mmmm yyyy',
  );
  cell(
    investmentSummary,
    'A3',
    text(t('จำนวนกองทุน', 'Number of funds')),
    bold: true,
  );
  cell(investmentSummary, 'B3', IntCellValue(data.fundCount));
  cell(
    investmentSummary,
    'A4',
    text(t('เงินลงทุนเดือนนี้', 'Investment this month')),
    bold: true,
  );
  cell(
    investmentSummary,
    'B4',
    DoubleCellValue(data.investedInMonth(data.investmentMonth) / 100),
    format: money,
    fill: yellow,
  );
  cell(investmentSummary, 'A5', text(t('สกุลเงิน', 'Currency')));
  cell(investmentSummary, 'B5', text(data.options.currencyCode));
  headers(investmentSummary, 7, 0, [
    t('เดือน', 'Month'),
    t('จำนวนกองทุน', 'Number of funds'),
    t('เงินลงทุนในเดือน', 'Monthly investment'),
    t('สกุลเงิน', 'Currency'),
  ]);
  var investmentRow = 8;
  for (final year in data.options.years) {
    for (var month = 1; month <= 12; month++) {
      final period = DateTime(year, month), r = investmentRow++;
      cell(investmentSummary, 'A$r', date(period), format: 'mmmm yyyy');
      cell(investmentSummary, 'B$r', IntCellValue(data.fundCount));
      cell(
        investmentSummary,
        'C$r',
        DoubleCellValue(data.investedInMonth(period) / 100),
        format: money,
        fill: yellow,
      );
      cell(investmentSummary, 'D$r', text(data.options.currencyCode));
    }
  }
  investmentSummary.freezePanes(rows: 7);
  wb.recalculate();
  return Uint8List.fromList(wb.save()!);
}
