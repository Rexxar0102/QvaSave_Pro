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
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<QvaNavDestination> items;
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Container(
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
        // FAB: Add download.
        Positioned(
          top: -10,
          child: GestureDetector(
            onTap: onAddPressed,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: QvaColors.oliveFab,
                borderRadius: BorderRadius.circular(18),
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