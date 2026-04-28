import 'package:diet_cure/utils/app_styles.dart';
import 'package:flutter/material.dart';

class AppNavigationRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const AppNavigationRail({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    });

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      minWidth: 200,
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      labelType: NavigationRailLabelType.all,
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.account_box, size: 75, color: AppTheme.warmSand,), 
          label: Text("Clients List")
        ),
        NavigationRailDestination(
          icon: Icon(Icons.all_inbox, size: 75, color: AppTheme.warmSand,), 
          label: Text("Diet Plans")
        )
      ],
    );
  }
}