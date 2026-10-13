import 'app_menu_styles.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Shared select styled like the React/MUI dropdown, using native Flutter menus.
class AppDropdown<T> extends StatefulWidget {
  const AppDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.decoration = const InputDecoration(),
    this.compact = false,
  });
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration decoration;
  final bool compact;
  @override
  State<AppDropdown<T>> createState() => _AppDropdownState<T>();
}

class _AppDropdownState<T> extends State<AppDropdown<T>> {
  final controller = MenuController();
  bool open = false;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    final available = widget.items.where((item) => item.value == widget.value);
    final selected = available.isEmpty ? null : available.first;
    final enabled =
        widget.onChanged != null && widget.items.any((item) => item.enabled);
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = MediaQuery.sizeOf(context);
        final triggerWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 128.0;
        final menuWidth = math.min(triggerWidth, screen.width - 24);
        return MenuAnchor(
          controller: controller,
          useRootOverlay: true,
          alignmentOffset: const Offset(0, 6),
          onOpen: () => setState(() => open = true),
          onClose: () {
            if (mounted) setState(() => open = false);
          },
          style: appMenuStyle(context).copyWith(
            minimumSize: WidgetStatePropertyAll(Size(menuWidth, 0)),
            maximumSize: WidgetStatePropertyAll(
              Size(menuWidth, math.min(320, screen.height * .6)),
            ),
          ),
          menuChildren: [
            for (final item in widget.items)
              SizedBox(
                width: menuWidth - 12,
                child: MenuItemButton(
                  key: ValueKey('dropdown-option-${item.value}'),
                  closeOnActivate: true,
                  onPressed: !enabled || !item.enabled
                      ? null
                      : () => widget.onChanged?.call(item.value),
                  style: appMenuItemStyle(
                    context,
                    selected: item.value == widget.value,
                  ),
                  trailingIcon: Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: item.value == widget.value
                        ? colors.primary
                        : Colors.transparent,
                  ),
                  child: DefaultTextStyle.merge(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Prompt',
                      fontSize: 14,
                      fontWeight: item.value == widget.value
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    child: item.child,
                  ),
                ),
              ),
          ],
          builder: (context, controller, child) => Semantics(
            button: true,
            enabled: enabled,
            expanded: open,
            child: InkWell(
              onTap: enabled
                  ? () => controller.isOpen
                        ? controller.close()
                        : controller.open()
                  : null,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                isEmpty: selected == null,
                isFocused: open,
                decoration: widget.decoration.copyWith(
                  enabled: enabled,
                  isDense: true,
                  filled: true,
                  fillColor: colors.surface,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: widget.compact ? 10 : 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.primary),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: DefaultTextStyle.merge(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Prompt',
                          fontSize: 14,
                          color: enabled
                              ? colors.onSurface
                              : colors.onSurface.withValues(alpha: .38),
                        ),
                        child: selected?.child ?? const Text(''),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: open ? .5 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: open ? colors.primary : colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AppDropdownFormField<T> extends FormField<T> {
  AppDropdownFormField({
    super.key,
    T? initialValue,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
    InputDecoration decoration = const InputDecoration(),
    bool isExpanded = true,
    super.validator,
  }) : super(
         initialValue: initialValue,
         enabled: onChanged != null,
         builder: (state) => AppDropdown<T>(
           value: state.value,
           items: items,
           decoration: decoration.copyWith(errorText: state.errorText),
           onChanged: onChanged == null
               ? null
               : (value) {
                   state.didChange(value);
                   onChanged(value);
                 },
         ),
       );
}
