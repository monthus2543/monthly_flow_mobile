import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monthly_flow/main.dart';
import 'package:monthly_flow/widgets/app_dropdown.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Prompt')
      ..addFont(rootBundle.load('assets/fonts/Prompt-Regular.ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final brightness in Brightness.values) {
    testWidgets('compact language menu matches its field width $brightness', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(brightness, 'teal'),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 128,
                child: AppDropdown<String>(
                  key: const ValueKey('language'),
                  compact: true,
                  value: 'th',
                  items: const [
                    DropdownMenuItem(value: 'th', child: Text('ไทย')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('language')));
      await tester.pumpAndSettle();
      final menu = find.byWidgetPredicate(
        (widget) =>
            widget is Material &&
            widget.shape is RoundedRectangleBorder &&
            (widget.shape as RoundedRectangleBorder).borderRadius ==
                BorderRadius.circular(18),
      );
      expect(menu, findsOneWidget);
      expect(
        tester.getSize(menu).width,
        tester.getSize(find.byKey(const ValueKey('language'))).width,
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      'menu anchors below field, scrolls, selects and fits Thai small screens $brightness',
      (tester) async {
        final previousShadows = debugDisableShadows;
        debugDisableShadows = false;
        try {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final boundary = GlobalKey();
          int selected = 0;
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: appTheme(brightness, 'orange'),
                home: Scaffold(
                  body: MediaQuery(
                    data: const MediaQueryData(
                      size: Size(320, 640),
                      textScaler: TextScaler.linear(1.3),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 80, 20, 0),
                      child: StatefulBuilder(
                        builder: (context, setState) => Column(
                          children: [
                            AppDropdown<int>(
                              key: const ValueKey('field'),
                              value: selected,
                              decoration: const InputDecoration(
                                labelText: 'หมวดหมู่',
                              ),
                              items: [
                                for (var i = 0; i < 25; i++)
                                  DropdownMenuItem(
                                    value: i,
                                    child: Text(
                                      i == 0
                                          ? 'อาหารและเครื่องดื่ม'
                                          : 'หมวดหมู่รายการที่มีชื่อยาวมาก $i',
                                    ),
                                  ),
                              ],
                              onChanged: (value) =>
                                  setState(() => selected = value!),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.byKey(const ValueKey('field')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            tester
                .getTopLeft(find.byKey(const ValueKey('dropdown-option-0')))
                .dy,
            greaterThan(
              tester.getBottomLeft(find.byKey(const ValueKey('field'))).dy,
            ),
          );
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final folder = Directory('build/dropdown-preview')
              ..createSync(recursive: true);
            File(
              '${folder.path}/${brightness.name}.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
          await tester.ensureVisible(
            find.byKey(const ValueKey('dropdown-option-24')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('dropdown-option-24')));
          await tester.pumpAndSettle();
          expect(selected, 24);
          expect(find.byType(MenuItemButton), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          debugDisableShadows = previousShadows;
        }
      },
    );
  }
  testWidgets(
    'disabled dropdown cannot open and required form selection validates',
    (tester) async {
      final form = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: form,
              child: Column(
                children: [
                  AppDropdown<int>(
                    key: const ValueKey('disabled'),
                    value: 1,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Disabled')),
                    ],
                    onChanged: null,
                  ),
                  AppDropdownFormField<int>(
                    key: const ValueKey('required'),
                    items: const [
                      DropdownMenuItem(value: 2, child: Text('Choice')),
                    ],
                    onChanged: (_) {},
                    validator: (value) => value == null ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('disabled')));
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('required')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dropdown-option-2')));
      await tester.pumpAndSettle();
      expect(form.currentState!.validate(), isTrue);
      await tester.pump();
      expect(find.text('Required'), findsNothing);
    },
  );
}
