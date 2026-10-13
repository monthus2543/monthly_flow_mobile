import 'package:flutter/material.dart';
import 'app_menu_styles.dart';

class AppActionMenu extends StatelessWidget {
  const AppActionMenu({
    super.key,
    required this.tooltip,
    required this.actions,
    required this.onSelected,
  });
  final String tooltip;
  final List<(String, String, IconData)> actions;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => MenuAnchor(
    useRootOverlay: true,
    alignmentOffset: const Offset(-184, 0),
    style: appMenuStyle(context).copyWith(
      alignment: AlignmentDirectional.topEnd,
      padding: const WidgetStatePropertyAll(EdgeInsets.all(4)),
    ),
    menuChildren: [
      for (final action in actions)
        SizedBox(
          width: 176,
          child: MenuItemButton(
            onPressed: () => onSelected(action.$1),
            style: appMenuItemStyle(context).copyWith(
              minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
            leadingIcon: Icon(action.$3, size: 16),
            child: Text(
              action.$2,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
    ],
    builder: (context, controller, child) => IconButton(
      tooltip: tooltip,
      icon: const Icon(Icons.more_horiz_rounded),
      onPressed: () =>
          controller.isOpen ? controller.close() : controller.open(),
    ),
  );
}
