import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Navegación inferior estilo QvaSave Pro.
///
/// Barra oliva translúcida con borde superior negro, items con icono + label
/// en mayúsculas y marcador de estado activo, y un FAB central de "Agregar
/// descarga" que sobresale por encima de la barra.
class QvaNavBar extends StatelessWidget {
  const QvaNavBar({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.items,
    required this.onAddPressed,
    this.showAddButton = true,
  });

  /// Key de la superficie visible de la barra.
  static const barSurfaceKey = Key('qva-nav-bar-surface');

  /// Key del botón "+".
  static const addButtonKey = Key('qva-nav-add-button');

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<QvaNavDestination> items;
  final VoidCallback onAddPressed;

  /// Muestra el FAB "Agregar descarga". Se oculta en pestañas donde no aplica
  /// (por ejemplo Ajustes).
  final bool showAddButton;

  /// Altura del botón "+".
  static const double addButtonSize = 64;

  /// Hueco visible entre el borde inferior del botón "+" y el borde superior de
  /// la barra, para que se lea como un control aparte y no parte del menú.
  static const double addButtonGap = 8;

  /// Espacio reservado encima de la barra para alojar el botón "+".
  ///
  /// El botón debe quedar dentro de los bounds de este widget: el hit test de
  /// Flutter solo busca hijos dentro de los bounds del padre, así que un
  /// `Positioned(top: negativo)` lo deja visible pero inclicable, y ningún
  /// `Transform` lo arregla porque el `Stack` descarta el toque antes de llegar
  /// al hijo. Reservar el espacio mantiene el aspecto de "flota sobre la barra"
  /// y hace que el botón responda de verdad.
  static const double addButtonReserve =
      addButtonSize + addButtonGap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hueco transparente para que el botón "+" flote sobre la barra.
            SizedBox(height: addButtonReserve),
            Container(
              key: QvaNavBar.barSurfaceKey,
              color: QvaColors.navOverlay,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 1,
                    color: Colors.black,
                  ),
                  SizedBox(
                    height: 76,
                    child: Row(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(
                            child: _NavItem(
                              destination: items[i],
                              active: i == currentIndex,
                              onTap: () => onDestinationSelected(i),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Home indicator area.
                  Container(
                    height: 32,
                    alignment: Alignment.center,
                    child: Container(
                      width: 132,
                      height: 4,
                      decoration: BoxDecoration(
                        color: QvaColors.ink,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).padding.bottom,
                  ),
                ],
              ),
            ),
          ],
        ),
        // Boton "+": agregar descarga. Flota separado de la barra, con un hueco
        // visible de 8 px por encima del menú.
        //
        // Se mantiene siempre montado para poder animar la ocultacion; cuando
        // showAddButton es false se oculta y se ignoran los toques para no
        // dejar un boton invisible que aun responda al tap.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(
            child: IgnorePointer(
              ignoring: !showAddButton,
              child: AnimatedScale(
                scale: showAddButton ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: showAddButton ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onAddPressed,
                    child: Container(
                      key: QvaNavBar.addButtonKey,
                      width: addButtonSize,
                      height: addButtonSize,
                      decoration: BoxDecoration(
                        color: QvaColors.oliveFab,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0x26000000),
                          width: 1,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: QvaColors.glow,
                            offset: Offset(0, 10),
                            blurRadius: 24,
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Color(0xFFF2F2F7),
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class QvaNavDestination {
  const QvaNavDestination({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.active,
    required this.onTap,
  });

  final QvaNavDestination destination;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? QvaColors.ink : Colors.black87;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(destination.icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(
            destination.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.8,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          if (active)
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: QvaColors.ink,
                shape: BoxShape.circle,
              ),
            )
          else
            const SizedBox(height: 4),
        ],
      ),
    );
  }
}