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
    return Material(
      color: const Color(0xFFF8FAFA),
      child: Container(
        width: width,
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: Color(0xFFE0E5E5))),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              alignment: Alignment.centerLeft,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE0E5E5))),
              ),
              child: const Text(
                'STUDENT SUBMISSIONS',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6B7272),
                  fontSize: 11,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                key: const PageStorageKey('student-sidebar-scroll'),
                itemCount: _items.length,
                itemBuilder: (context, displayIndex) {
                  final item = _items[displayIndex];
                  final selected = item.index == widget.currentIndex;
                  final graded = widget.gradedAliases.contains(item.alias);
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: selected ? const Color(0xFFE8F3F1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => widget.onSelect(item.index),
                        hoverColor: const Color(0xFFE8F3F1).withOpacity(0.6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                graded ? Icons.check_circle_rounded : Icons.circle_outlined,
                                size: 16,
                                color: graded
                                    ? const Color(0xFF2E7D7D)
                                    : (selected ? const Color(0xFF1E4C4C) : const Color(0xFFB0B7B7)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.alias,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: selected ? const Color(0xFF1A1C1C) : const Color(0xFF4A5252),
                                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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
    if (items.isEmpty) return 160;
    final style = DefaultTextStyle.of(context).style.copyWith(fontSize: 14, fontWeight: FontWeight.w600);
    final direction = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final widestAlias = items
        .map((item) => _textWidth(item.alias, style, direction, textScaler))
        .reduce((a, b) => a > b ? a : b);
    const tileChromeWidth = 64.0;
    return (widestAlias + tileChromeWidth).clamp(200.0, 300.0);
  }

  double _textWidth(String text, TextStyle style, TextDirection direction, TextScaler textScaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  String _aliasKeyFor(List<String> aliases) => aliases.join('\n');
}

class _AliasItem {
  const _AliasItem(this.alias, this.index);
  final String alias;
  final int index;
}
