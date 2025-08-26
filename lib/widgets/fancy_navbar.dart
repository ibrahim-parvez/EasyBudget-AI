import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

class FancyNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onScanExpense;
  final VoidCallback onManualExpense;

  const FancyNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onScanExpense,
    required this.onManualExpense,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black.withOpacity(0.4) : Colors.white;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 10),
        child: Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(30),
          color: bg,
          child: SizedBox(
            height: 62, // slightly smaller
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  active: currentIndex == 0,
                  onTap: () => onTap(0),
                ),
                _NavItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Expenses',
                  active: currentIndex == 1,
                  onTap: () => onTap(1),
                ),

                // Floating center FAB (pops out)
                Transform.translate(
                  offset: const Offset(0, -20), // moves up by 20px
                  child: _CenterFab(
                    onScan: onScanExpense,
                    onManual: onManualExpense,
                  ),
                ),

                _NavItem(
                  icon: Icons.subscriptions_outlined,
                  label: 'Subscriptions',
                  active: currentIndex == 3,
                  onTap: () => onTap(3),
                ),
                _NavItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  active: currentIndex == 4,
                  onTap: () => onTap(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.blue500 : Colors.grey.shade600;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: SizedBox(
        width: 60, // slightly smaller width
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20), // smaller icon
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(fontSize: 10, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterFab extends StatelessWidget {
  final VoidCallback onScan;
  final VoidCallback onManual;

  const _CenterFab({required this.onScan, required this.onManual, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4), // border highlight
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: SpeedDial(
        icon: Icons.add,
        backgroundColor: AppColors.blue500,
        activeIcon: Icons.close,
        spacing: 12,
        spaceBetweenChildren: 12,
        elevation: 6,
        overlayColor: Colors.black.withOpacity(0.1),
        children: [
          SpeedDialChild(
            child: const Icon(Icons.camera_alt_rounded),
            label: 'Scan Receipt',
            onTap: onScan,
          ),
          SpeedDialChild(
            child: const Icon(Icons.edit_rounded),
            label: 'Enter Manually',
            onTap: onManual,
          ),
        ],
      ),
    );
  }
}
