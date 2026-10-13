import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monthly_flow/auth/auth_providers.dart';
import 'package:monthly_flow/l10n/app_localizations.dart';
import 'package:monthly_flow/main.dart';
import 'package:monthly_flow/screens/settings_screen.dart';
import 'package:monthly_flow/state/app_state.dart';
import 'package:monthly_flow/state/app_store.dart';
import 'package:monthly_flow/widgets/common_widgets.dart';

class CurrencyStore extends AppStore {
  @override
  AppState build() => AppState(localName: 'User', onboardingCompleted: true);
  @override
  Future<void> setCurrency(String code) async =>
      state = state.copyWith(currencyCode: code);
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('currency dropdown updates displayed amounts $brightness', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [
          appStoreProvider.overrideWith(CurrencyStore.new),
          authSessionProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) => MaterialApp(
              theme: appTheme(
                brightness,
                'purple',
                ref.watch(appStoreProvider).currencyCode,
              ),
              locale: const Locale('en'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizationsDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: Scaffold(
                body: Column(
                  children: [
                    Builder(builder: (context) => Text(money(context, 123456))),
                    const Expanded(child: SettingsScreen()),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('฿1,234.56'), findsOneWidget);
      await tester.ensureVisible(find.text('TH-฿'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TH-฿'));
      await tester.pumpAndSettle();
      final usd = find.byKey(const ValueKey('dropdown-option-USD'));
      expect(find.text('US-\$'), findsOneWidget);
      expect(find.text('SG-\$'), findsOneWidget);
      await tester.tapAt(tester.getCenter(usd));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(container.read(appStoreProvider).currencyCode, 'USD');
      expect(find.text('US-\$'), findsOneWidget);
      expect(find.text('\$1,234.56'), findsOneWidget);
      expect(find.text('฿1,234.56'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
