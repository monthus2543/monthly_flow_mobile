import 'package:flutter/material.dart';

MenuStyle appMenuStyle(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return MenuStyle(
    backgroundColor: WidgetStatePropertyAll(colors.surface),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: const WidgetStatePropertyAll(8),
    padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant),
      ),
    ),
  );
}

ButtonStyle appMenuItemStyle(BuildContext context, {bool selected = false}) {
  final colors = Theme.of(context).colorScheme;
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
    ),
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => selected
          ? colors.primary.withValues(alpha: .12)
          : states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused) ||
                states.contains(WidgetState.pressed)
          ? colors.primary.withValues(alpha: .08)
          : Colors.transparent,
    ),
    foregroundColor: WidgetStatePropertyAll(
      selected ? colors.primary : colors.onSurface,
    ),
    textStyle: WidgetStatePropertyAll(
      TextStyle(
        fontFamily: 'Prompt',
        fontSize: 14,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    ),
  );
}
