import '../widgets/app_dropdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import '../l10n/app_localizations.dart';
import '../state/app_store.dart';
import '../widgets/common_widgets.dart';
import '../widgets/account_card.dart';
import '../widgets/sync_status_card.dart';
import '../auth/auth_providers.dart';
import 'account_screen.dart';
import 'category_manager_screen.dart';
import 'planner_screen.dart';
import 'export_screen.dart';
import '../currency/app_currency.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  AppStore get store => ref.read(appStoreProvider.notifier);
  @override
  Widget build(BuildContext context) {
    ref.watch(appStoreProvider);
    final signedIn = ref.watch(authSessionProvider).asData?.value != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 110),
      children: [
        PageTitle(
          context.l10n.t('settings'),
          context.l10n.t('settings_subtitle'),
        ),
        const SizedBox(height: 16),
        const AccountCard(),
        const SizedBox(height: 13),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.t('display'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              AppSwitchTile(
                title: context.l10n.t('dark_mode'),
                value: store.darkMode,
                onChanged: store.setDarkMode,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.t('theme_color')),
                trailing: SizedBox(
                  width: 128,
                  child: AppDropdown<String>(
                    value: store.themeColor,
                    compact: true,
                    items: [
                      _themeItem(context, 'teal', AppColors.teal),
                      _themeItem(context, 'blue', AppColors.blue),
                      _themeItem(context, 'purple', AppColors.purple),
                      _themeItem(context, 'orange', AppColors.orange),
                      _themeItem(context, 'rose', AppColors.rose),
                    ],
                    onChanged: (value) {
                      if (value != null && value != store.themeColor) {
                        _changeThemeColor(context, value);
                      }
                    },
                  ),
                ),
              ),
              AppSwitchTile(
                title: context.l10n.t('hide_balances'),
                value: store.hideBalances,
                onChanged: store.setHideBalances,
              ),
              AppSwitchTile(
                title: context.l10n.t('reminders'),
                value: store.remindersEnabled,
                onChanged: store.setRemindersEnabled,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.t('app_pin')),
                subtitle: Text(
                  context.l10n.t(store.pinHash.isEmpty ? 'pin_off' : 'pin_on'),
                ),
                trailing: const Icon(Icons.lock_outline),
                onTap: () => _configurePin(context),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.t('language')),
                trailing: SizedBox(
                  width: 128,
                  child: AppDropdown<String>(
                    value: store.languageCode,
                    compact: true,
                    items: [
                      DropdownMenuItem(
                        value: 'th',
                        child: Text(context.l10n.t('thai')),
                      ),
                      DropdownMenuItem(
                        value: 'en',
                        child: Text(context.l10n.t('english')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null && value != store.languageCode) {
                        _changeLanguage(context, value);
                      }
                    },
                  ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.t('currency')),
                subtitle: Text(context.l10n.t('currency_display_only')),
                trailing: SizedBox(
                  width: 128,
                  child: AppDropdown<String>(
                    value: store.currencyCode,
                    compact: true,
                    items: [
                      for (final item in currencySelectionLabels.entries)
                        DropdownMenuItem(
                          value: item.key,
                          child: Semantics(
                            label: item.key,
                            child: Text(item.value),
                          ),
                        ),
                    ],
                    onChanged: (value) async {
                      if (value == null || value == store.currencyCode) return;
                      if (!context.mounted) return;
                      try {
                        await store.setCurrency(value);
                      } catch (_) {
                        if (context.mounted)
                          showAppAlert(
                            context,
                            context.l10n.t('save_failed'),
                            isError: true,
                          );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.t('my_data'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.t('planner')),
                leading: const Icon(Icons.auto_graph_outlined),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => PlannerScreen()),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.t('manage_categories')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => CategoryManagerScreen(),
                  ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.t('export_excel')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const ExportScreen()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.t('local_data'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                context.l10n.t('offline'),
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              if (signedIn) ...[
                const SyncStatusCard(),
                const SizedBox(height: 12),
                const Divider(),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onErrorContainer,
                    side: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.error.withValues(alpha: .5),
                    ),
                  ),
                  onPressed: () => _clear(context),
                  child: Text(context.l10n.t('clear_all')),
                ),
              ),
            ],
          ),
        ),
        if (signedIn) ...[
          const SizedBox(height: 16),
          // Match the Surface's 18 px padding plus its 1 px border.
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 19),
            child: AccountSignOutButton(),
          ),
        ],
      ],
    );
  }

  DropdownMenuItem<String> _themeItem(
    BuildContext context,
    String value,
    Color color,
  ) => DropdownMenuItem(
    value: value,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            context.l10n.t('theme_$value'),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );

  Future<void> _changeThemeColor(BuildContext context, String value) async {
    if (context.mounted) await store.setThemeColor(value);
  }

  Future<void> _changeLanguage(BuildContext context, String code) async {
    // MenuItemButton runs this after the menu closes and focus is restored.
    if (context.mounted) await store.setLanguage(code);
  }

  Future<void> _configurePin(BuildContext context) async {
    final appStore = store;
    final enabled = appStore.pinHash.isNotEmpty;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _PinDialog(enabled: enabled),
    );
    if (!mounted || result == null) return;
    await appStore.setPin(result);
  }

  Future<void> _clear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.t('clear_title')),
        content: Text(context.l10n.t('clear_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.t('clear')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await store.clearEntries();
      if (context.mounted) showAppAlert(context, context.l10n.t('cleared'));
    }
  }
}

class _PinDialog extends StatefulWidget {
  final bool enabled;
  const _PinDialog({required this.enabled});
  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    constraints: const BoxConstraints(maxWidth: 360),
    title: Text(context.l10n.t('app_pin')),
    content: SizedBox(
      height: 56,
      child: Pinput(
        controller: controller,
        length: 6,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        defaultPinTheme: _pinTheme(context),
        focusedPinTheme: _pinTheme(context).copyWith(
          decoration: _pinTheme(context).decoration?.copyWith(
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
        ),
      ),
    ),
    actions: [
      if (widget.enabled)
        TextButton(
          onPressed: () => Navigator.pop(context, ''),
          child: Text(context.l10n.t('remove_pin')),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.t('cancel')),
      ),
      FilledButton(
        onPressed: () {
          if (controller.text.length >= 4)
            Navigator.pop(context, controller.text);
        },
        child: Text(context.l10n.t('save')),
      ),
    ],
  );

  PinTheme _pinTheme(BuildContext context) => PinTheme(
    width: ((MediaQuery.sizeOf(context).width - 96 - 40) / 6).clamp(24.0, 42.0),
    height: 52,
    textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
  );
}
