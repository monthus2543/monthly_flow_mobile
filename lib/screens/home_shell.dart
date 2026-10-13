import 'investment_entry_sheet.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../l10n/app_localizations.dart';
import '../widgets/common_widgets.dart';
import 'dashboard_screen.dart';
import 'entry_form_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'transactions_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  bool investmentMode = false;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        onNavigate: _selectPage,
        investmentMode: investmentMode,
        onInvestmentModeChanged: (v) => setState(() => investmentMode = v),
      ),
      TransactionsScreen(),
      StatisticsScreen(),
      SettingsScreen(),
    ];
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: appBackgroundGradient(context)),
        child: SafeArea(
          child: IndexedStack(index: index, children: pages),
        ),
      ),
      extendBody: true,
      floatingActionButton: SizedBox.square(
        dimension: 58,
        child: FloatingActionButton(
          onPressed: _openEntryForm,
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          shape: const CircleBorder(),
          elevation: 8,
          child: const Icon(Icons.add_rounded, size: 29),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        height: 62,
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
        notchMargin: 8,
        shape: const CircularNotchedRectangle(),
        child: Row(
          children: [
            Expanded(
              child: _BottomNavItem(
                icon: LucideIcons.house,
                selectedIcon: LucideIcons.house600,
                label: context.l10n.t('dashboard'),
                selected: index == 0,
                onTap: () => _selectPage(0),
              ),
            ),
            Expanded(
              child: _BottomNavItem(
                icon: LucideIcons.receiptText,
                selectedIcon: LucideIcons.receiptText600,
                label: context.l10n.t('transactions'),
                selected: index == 1,
                onTap: () => _selectPage(1),
              ),
            ),
            const SizedBox(width: 68),
            Expanded(
              child: _BottomNavItem(
                icon: LucideIcons.chartNoAxesColumn,
                selectedIcon: LucideIcons.chartNoAxesColumn600,
                label: context.l10n.t('statistics'),
                selected: index == 2,
                onTap: () => _selectPage(2),
              ),
            ),
            Expanded(
              child: _BottomNavItem(
                icon: LucideIcons.settings,
                selectedIcon: LucideIcons.settings600,
                label: context.l10n.t('settings'),
                selected: index == 3,
                onTap: () => _selectPage(3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectPage(int value) {
    if (index != value) setState(() => index = value);
  }

  Future<void> _openEntryForm() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .94,
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final scheme = theme.colorScheme;
        final backgroundColor =
            theme.bottomSheetTheme.modalBackgroundColor ?? scheme.surface;
        return Theme(
          data: theme.copyWith(
            scaffoldBackgroundColor: backgroundColor,
            appBarTheme: theme.appBarTheme.copyWith(
              backgroundColor: backgroundColor,
              surfaceTintColor: theme.bottomSheetTheme.surfaceTintColor,
            ),
          ),
          child: index == 0 && investmentMode
              ? const InvestmentEntrySheet()
              : const EntryFormScreen(),
        );
      },
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = selected ? colorScheme.primary : colorScheme.onSurfaceVariant;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: selected ? colorScheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: .18),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : const [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? selectedIcon : icon, color: color, size: 20),
              const SizedBox(height: 1),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
