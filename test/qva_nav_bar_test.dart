import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qvasave_pro/shared/widgets/qva_nav_bar.dart';

Widget _harness({
  required int currentIndex,
  required VoidCallback onAddPressed,
  bool showAddButton = true,
}) {
  return MaterialApp(
    home: Scaffold(
      body: const SizedBox.expand(),
      bottomNavigationBar: QvaNavBar(
        currentIndex: currentIndex,
        onDestinationSelected: (_) {},
        onAddPressed: onAddPressed,
        showAddButton: showAddButton,
        items: const [
          QvaNavDestination(icon: Icons.home_outlined, label: 'Inicio'),
          QvaNavDestination(icon: Icons.history, label: 'Historial'),
          QvaNavDestination(icon: Icons.tune, label: 'Ajustes'),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('El boton + responde al tap y abre la accion de agregar', (
    WidgetTester tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _harness(currentIndex: 0, onAddPressed: () => taps++),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.add), findsOneWidget);

    // El FAB se dibuja por encima del borde superior de la barra, fuera de los
    // bounds del Stack. Un top negativo lo deja visible pero inclicable; el
    // transform es lo que mantiene el hit test funcionando.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('El boton + se muestra en Inicio e Historial', (
    WidgetTester tester,
  ) async {
    for (final index in [0, 1]) {
      await tester.pumpWidget(
        _harness(currentIndex: index, onAddPressed: () {}),
      );
      await tester.pumpAndSettle();

      final opacity = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byIcon(Icons.add),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(
        opacity.opacity,
        1,
        reason: 'El FAB debe ser visible en la pestaña $index',
      );
    }
  });

  testWidgets('El boton + se oculta y no responde en Ajustes', (
    WidgetTester tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _harness(
        currentIndex: 2,
        onAddPressed: () => taps++,
        showAddButton: false,
      ),
    );
    await tester.pumpAndSettle();

    final opacity = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.byIcon(Icons.add),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(opacity.opacity, 0);

    // Sigue montado para poder animarse, pero no debe capturar toques.
    await tester.tap(find.byIcon(Icons.add), warnIfMissed: false);
    await tester.pump();

    expect(taps, 0);
  });

  testWidgets('El boton + queda separado de la barra por 8 px', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_harness(currentIndex: 0, onAddPressed: () {}));
    await tester.pumpAndSettle();

    final addBottom = tester
        .getBottomLeft(find.byKey(QvaNavBar.addButtonKey))
        .dy;
    final barTop = tester
        .getTopLeft(find.byKey(QvaNavBar.barSurfaceKey))
        .dy;

    expect(barTop - addBottom, QvaNavBar.addButtonGap);
  });

  testWidgets('El boton + no se superpone al contenido del cuerpo', (
    WidgetTester tester,
  ) async {
    const bodyKey = Key('harness-body');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(key: bodyKey),
          bottomNavigationBar: QvaNavBar(
            currentIndex: 0,
            onDestinationSelected: (_) {},
            onAddPressed: () {},
            items: const [
              QvaNavDestination(icon: Icons.home_outlined, label: 'Inicio'),
              QvaNavDestination(icon: Icons.history, label: 'Historial'),
              QvaNavDestination(icon: Icons.tune, label: 'Ajustes'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bodyBottom = tester.getBottomLeft(find.byKey(bodyKey)).dy;
    final addTop = tester.getTopLeft(find.byKey(QvaNavBar.addButtonKey)).dy;

    // El espacio del boton se reserva arriba de la barra, asi que el cuerpo
    // termina justo donde empieza el boton y nada queda tapado.
    expect(bodyBottom, addTop);
  });
}