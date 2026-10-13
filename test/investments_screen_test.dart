import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monthly_flow/main.dart';
import 'package:monthly_flow/models/investment.dart';
import 'package:monthly_flow/models/finance_models.dart';
import 'package:monthly_flow/l10n/app_localizations.dart';
import 'package:monthly_flow/screens/investments_screen.dart';
import 'package:monthly_flow/screens/dashboard_screen.dart';
import 'package:monthly_flow/screens/home_shell.dart';
import 'package:monthly_flow/screens/investment_entry_sheet.dart';
import 'package:monthly_flow/models/investment_entry.dart';
import 'package:monthly_flow/auth/auth_providers.dart';
import 'support/fake_auth_repository.dart';
import 'package:monthly_flow/state/app_store.dart';
import 'package:monthly_flow/state/app_state.dart';
import 'package:monthly_flow/widgets/wallet_balance_card.dart';
import 'package:monthly_flow/widgets/common_widgets.dart';

class TestPortfolioStore extends AppStore {
  @override
  AppState build() => AppState(
    accounts: const [Account(id: 1, name: 'cash')],
    investments: [
      Investment(
        id: 1,
        name: 'กองทุนสำรอง',
        investedMinor: 100000,
        currentMinor: 120000,
        currencyCode: 'THB',
        valuedAt: DateTime(2026, 10, 13),
      ),
      Investment(
        id: 2,
        name: 'US portfolio',
        investedMinor: 100000,
        currentMinor: 300000,
        currencyCode: 'USD',
        valuedAt: DateTime(2026, 10, 13),
      ),
    ],
  );
  @override
  Future<void> addInvestmentEntry(InvestmentEntry entry) async =>
      state = state.copyWith(
        investmentEntries: [
          ...state.investmentEntries.where(
            (e) => entry.id == null || e.id != entry.id,
          ),
          entry,
        ],
      );
  @override
  Future<void> deleteInvestmentEntry(int id) async => state = state.copyWith(
    investmentEntries: state.investmentEntries
        .where((e) => e.id != id)
        .toList(),
  );
  @override
  Future<void> saveFund(Investment value) async =>
      state = state.copyWith(investments: [...state.investments, value]);
}

void main() {
  setUpAll(() async {
    for (final family in ['Prompt', 'MaterialIcons']) {
      final loader = FontLoader(family)
        ..addFont(
          rootBundle.load(
            family == 'Prompt'
                ? 'assets/fonts/Prompt-Regular.ttf'
                : 'fonts/MaterialIcons-Regular.otf',
          ),
        );
      await loader.load();
    }
  });
  testWidgets(
    'edit deposit preloads values and saves corrections without valuation input',
    (tester) async {
      final container = ProviderContainer(
        overrides: [appStoreProvider.overrideWith(TestPortfolioStore.new)],
      );
      addTearDown(container.dispose);
      final entry = InvestmentEntry(
        id: 10,
        fundId: 1,
        accountId: 1,
        amountMinor: 100000,
        currentMinor: 0,
        contributionOnly: true,
        date: DateTime(2026, 10, 1),
        createdAt: 1,
        note: 'Original',
      );
      await container.read(appStoreProvider.notifier).addInvestmentEntry(entry);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: appTheme(Brightness.light, 'orange'),
            locale: const Locale('th'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: InvestmentEntrySheet(entry: entry),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('แก้ไขการลงทุน'), findsOneWidget);
      expect(find.text('1000.00'), findsOneWidget);
      expect(find.text('มูลค่าพอร์ต'), findsNothing);
      await tester.enterText(find.byType(TextFormField).first, '500');
      await tester.scrollUntilVisible(
        find.byType(FilledButton),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      final saved = container.read(appStoreProvider).investmentEntries.single;
      expect(saved.id, 10);
      expect(saved.amountMinor, 50000);
      expect(saved.createdAt, 1);
      expect(tester.takeException(), isNull);
    },
  );
  for (final brightness in Brightness.values)
    testWidgets('investment cash debit stays yellow $brightness', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [appStoreProvider.overrideWith(TestPortfolioStore.new)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: appTheme(brightness, 'purple'),
            locale: const Locale('th'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: TransactionTile(
                entry: Entry(
                  id: -1,
                  title: 'Fund',
                  amountMinor: 100000,
                  type: investmentTransfer,
                  categoryId: -1,
                  accountId: 1,
                  date: DateTime(2026, 10, 13),
                  createdAt: 1,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('−฿1,000.00')).style!.color,
        AppColors.investment,
      );
      expect(find.textContaining('ลงทุน · เงินสด'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  testWidgets(
    'dashboard mode opens portfolio management without mixing currencies',
    (tester) async {
      final container = ProviderContainer(
        overrides: [appStoreProvider.overrideWith(TestPortfolioStore.new)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: appTheme(Brightness.light, 'orange'),
            locale: const Locale('th'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Scaffold(body: DashboardScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('ลงทุน'));
      await tester.pumpAndSettle();
      expect(find.text('มูลค่าพอร์ต'), findsOneWidget);
      expect(find.text('US portfolio'), findsNothing);
      await tester.tap(find.text('เพิ่มกองทุน'));
      await tester.pumpAndSettle();
      expect(find.text('ชื่อกองทุน / สินทรัพย์'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final brightness in Brightness.values)
    testWidgets('centre add opens investment sheet with keyboard $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final auth = FakeAuthRepository();
      final container = ProviderContainer(
        overrides: [
          appStoreProvider.overrideWith(TestPortfolioStore.new),
          authRepositoryProvider.overrideWith((ref) async => auth),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await auth.dispose();
      });
      final previewBoundary = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: RepaintBoundary(
            key: previewBoundary,
            child: MaterialApp(
              theme: appTheme(brightness, 'orange'),
              locale: const Locale('th'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizationsDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const HomeShell(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('ลงทุน'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(InvestmentEntrySheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(InvestmentEntrySheet),
          matching: find.text('—'),
        ),
        findsNothing,
      );
      final theme = Theme.of(tester.element(find.byType(InvestmentEntrySheet)));
      expect(
        theme.scaffoldBackgroundColor,
        theme.bottomSheetTheme.modalBackgroundColor,
      );
      await tester.tap(
        find
            .descendant(
              of: find.byType(InvestmentEntrySheet),
              matching: find.byType(InputDecorator),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dropdown-option-1')));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '1000');
      expect(
        find.descendant(
          of: find.byType(InvestmentEntrySheet),
          matching: find.text('มูลค่าพอร์ต'),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image =
            await (previewBoundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('build/investment-preview').createSync(recursive: true);
        File(
          'build/investment-preview/entry-${brightness.name}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.descendant(
          of: find.byType(InvestmentEntrySheet),
          matching: find.byType(FilledButton),
        ),
        120,
        scrollable: find
            .descendant(
              of: find.byType(InvestmentEntrySheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find
            .descendant(
              of: find.byType(InvestmentEntrySheet),
              matching: find.byType(ListView),
            )
            .first,
        const Offset(0, -180),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.descendant(
          of: find.byType(InvestmentEntrySheet),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      final entry = container.read(appStoreProvider).investmentEntries.single;
      expect(entry.fundId, 1);
      expect(entry.accountId, 1);
      expect(entry.amountMinor, 100000);
      expect(entry.contributionOnly, isTrue);
      expect(find.byType(InvestmentEntrySheet), findsNothing);
    });
  for (final brightness in Brightness.values)
    testWidgets(
      'manual portfolio editor fits small screens and keeps currencies separate $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 680);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = ProviderContainer(
          overrides: [appStoreProvider.overrideWith(TestPortfolioStore.new)],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: appTheme(brightness, 'orange'),
              locale: const Locale('th'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizationsDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const InvestmentsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('US portfolio'), findsNothing);
        expect(find.text('กองทุนสำรอง'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('เพิ่มกองทุน'));
        await tester.pumpAndSettle();
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'พอร์ตใหม่');
        await tester.enterText(fields.at(1), 'หมายเหตุ');
        await tester.scrollUntilVisible(
          find.byType(FilledButton),
          180,
          scrollable: find
              .descendant(
                of: find.byType(ListView).last,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(container.read(appStoreProvider).investments.last.gainMinor, 0);
        expect(tester.takeException(), isNull);
      },
    );
  for (final brightness in Brightness.values)
    testWidgets(
      'wallet investment toggle and hidden values fit Thai card $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundary = GlobalKey();
        bool mode = false;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: appTheme(brightness, 'orange'),
              locale: const Locale('th'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizationsDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(18),
                  child: StatefulBuilder(
                    builder: (context, setState) => WalletBalanceCard(
                      incomeMinor: 200000,
                      expenseMinor: 50000,
                      investmentMode: mode,
                      fundCount: 2,
                      monthlyInvestedMinor: 100000,
                      currentMinor: 120000,
                      onToggleMode: () => setState(() => mode = !mode),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byTooltip('ลงทุน'));
        await tester.pumpAndSettle();
        expect(find.text('มูลค่าพอร์ต'), findsOneWidget);
        expect(find.text('฿1,200.00'), findsOneWidget);
        expect(find.text('จำนวนกองทุน'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('฿1,000.00'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory('build/investment-preview').createSync(recursive: true);
          File(
            'build/investment-preview/${brightness.name}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.tap(find.byTooltip('เงินใช้จ่าย'));
        await tester.pumpAndSettle();
        expect(find.text('ยอดคงเหลือเดือนนี้'), findsOneWidget);
      },
    );
}
