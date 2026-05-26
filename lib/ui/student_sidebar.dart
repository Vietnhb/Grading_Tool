import 'package:flutter/material.dart';

import '../core/file_name_utils.dart';

class StudentSidebar extends StatefulWidget {
  const StudentSidebar({
    required this.aliases,
    required this.currentIndex,
    required this.gradedAliases,
    required this.onSelect,
    super.key,
  });

  final List<String> aliases;
  final int currentIndex;
  final Set<String> gradedAliases;
  final ValueChanged<int> onSelect;

  @override
  State<StudentSidebar> createState() => _StudentSidebarState();
}

class _StudentSidebarState extends State<StudentSidebar> {
  List<_AliasItem> _items = const [];
  String _aliasKey = '';
  double? _width;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshItems();
    _width = null;
  }

  @override
  void didUpdateWidget(covariant StudentSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_aliasKeyFor(widget.aliases) != _aliasKey) {
      _refreshItems();
      _width = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = _width ??= _sidebarWidth(context, _items);
    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE0E5E5))),
      ),
      child: ListView.builder(
        key: const PageStorageKey('student-sidebar-scroll'),
        itemCount: _items.length,
        itemBuilder: (context, displayIndex) {
          final item = _items[displayIndex];
          final selected = item.index == widget.currentIndex;
          final graded = widget.gradedAliases.contains(item.alias);
          return ListTile(
            dense: true,
            selected: selected,
            selectedColor: const Color(0xFF0D2F2F),
            selectedTileColor: const Color(0xFFD3E5E1),
            shape: Border(
              left: BorderSide(
                width: 4,
                color: selected ? const Color(0xFF173D3D) : Colors.transparent,
              ),
            ),
            leading: Icon(
              graded ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: graded ? const Color(0xFF2F5E5E) : const Color(0xFF98A2A2),
            ),
            title: Text(
              item.alias,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
              ),
            ),
            onTap: () => widget.onSelect(item.index),
          );
        },
      ),
    );
  }

  void _refreshItems() {
    _aliasKey = _aliasKeyFor(widget.aliases);
    _items = [
      for (var index = 0; index < widget.aliases.length; index += 1)
        _AliasItem(widget.aliases[index], index),
    ]..sort((a, b) => compareAliases(a.alias, b.alias));
  }

  double _sidebarWidth(BuildContext context, List<_AliasItem> items) {
    if (items.isEmpty) {
      return 112;
    }

    final style = DefaultTextStyle.of(context).style;
    final direction = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final widestAlias = items
        .map((item) => _textWidth(item.alias, style, direction, textScaler))
        .reduce((a, b) => a > b ? a : b);

    const tileChromeWidth = 84.0;
    return (widestAlias + tileChromeWidth).clamp(112.0, 190.0);
  }

  double _textWidth(
    String text,
    TextStyle style,
    TextDirection direction,
    TextScaler textScaler,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  String _aliasKeyFor(List<String> aliases) {
    return aliases.join('\n');
  }
}

class _AliasItem {
  const _AliasItem(this.alias, this.index);

  final String alias;
  final int index;
}
