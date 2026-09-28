// This is a basic Flutter widget test for QvaSave Pro

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qvasave_pro/core/providers/service_providers.dart';
import 'package:qvasave_pro/main.dart';

void main() {
  testWidgets('App startup smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [languageProvider.overrideWith((ref) => 'es')],
        child: const QvaSaveApp(),
      ),
    );

    expect(find.text('Inicio'), findsWidgets);
    expect(find.text('Historial'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
  });
}
