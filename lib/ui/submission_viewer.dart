import 'dart:io';

import 'package:flutter/material.dart';

import '../grading/grading_models.dart';
import '../submission/submission_models.dart';

class SubmissionViewer extends StatefulWidget {
  const SubmissionViewer({
    required this.submission,
    required this.questionImage,
    required this.gradingGuide,
    super.key,
  });

  final StudentSubmission submission;
  final File questionImage;
  final GradingGuide gradingGuide;

  @override
  State<SubmissionViewer> createState() => _SubmissionViewerState();
}

class _SubmissionViewerState extends State<SubmissionViewer>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  var _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_refreshCurrentTab);
  }

  @override
  void dispose() {
    _tabController.removeListener(_refreshCurrentTab);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF173D3D),
            tabs: const [
              Tab(text: 'Submission'),
              Tab(text: 'Grading Guide'),
              Tab(text: 'Question'),
            ],
          ),
        ),
        Expanded(child: RepaintBoundary(child: _currentTab())),
      ],
    );
  }

  Widget _currentTab() {
    return switch (_tabIndex) {
      0 => _SubmissionText(
        key: ValueKey(widget.submission.alias),
        submission: widget.submission,
      ),
      1 => _GradingGuideView(guide: widget.gradingGuide),
      _ => _QuestionImage(file: widget.questionImage),
    };
  }

  void _refreshCurrentTab() {
    if (_tabIndex != _tabController.index) {
      setState(() {
        _tabIndex = _tabController.index;
      });
    }
  }
}

class _GradingGuideView extends StatelessWidget {
  const _GradingGuideView({required this.guide});

  final GradingGuide guide;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF3F5F7),
      child: ListView(
        key: const PageStorageKey('grading-guide-scroll'),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        children: [
          Center(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0xFFE1E5E8)),
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1220),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(34, 28, 34, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final block in guide.blocks)
                        _GuideBlockView(block: block),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideBlockView extends StatelessWidget {
  const _GuideBlockView({required this.block});

  final DocumentBlock block;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      SectionBlock(:final heading, :final children) => _GuideSection(
        heading: heading,
        children: children,
      ),
      ParagraphBlock(:final text) => _GuideText(
        text,
        padding: const EdgeInsets.only(bottom: 10),
        style: _GuideStyle.paragraph,
      ),
      BulletListBlock(:final items) => _GuideList(items: items),
      RubricTableBlock(:final rows) => _GuideTable(rows: rows),
    };
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({required this.heading, required this.children});

  final HeadingBlock heading;
  final List<DocumentBlock> children;

  @override
  Widget build(BuildContext context) {
    final style = heading.level <= 1 ? _GuideStyle.title : _GuideStyle.section;
    final padding = heading.level <= 1
        ? const EdgeInsets.only(bottom: 28)
        : const EdgeInsets.only(top: 18, bottom: 10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GuideText(heading.text, padding: padding, style: style),
        for (final child in children) _GuideBlockView(block: child),
      ],
    );
  }
}

class _GuideText extends StatelessWidget {
  const _GuideText(this.text, {required this.padding, required this.style});

  final String text;
  final EdgeInsets padding;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(text, style: style),
    );
  }
}

class _GuideList extends StatelessWidget {
  const _GuideList({required this.items});

  final List<BulletListItemBlock> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in items)
            Padding(
              padding: EdgeInsets.only(left: 18 + (item.level * 18), bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: SizedBox.square(
                      dimension: 5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFF2B73C2),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item.text, style: _GuideStyle.paragraph),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GuideTable extends StatelessWidget {
  const _GuideTable({required this.rows});

  final List<RubricTableRowBlock> rows;

  @override
  Widget build(BuildContext context) {
    final columnCount = rows.fold<int>(
      0,
      (count, row) => row.cells.length > count ? row.cells.length : count,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD9DEE2)),
        ),
        child: Column(
          children: [
            for (var index = 0; index < rows.length; index += 1)
              _GuideRow(
                row: rows[index],
                last: index == rows.length - 1,
                columnCount: columnCount,
              ),
          ],
        ),
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({
    required this.row,
    required this.last,
    required this.columnCount,
  });

  final RubricTableRowBlock row;
  final bool last;
  final int columnCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: row.isHeader ? const Color(0xFFF1F5F8) : null,
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFD9DEE2))),
      ),
      child: Row(
        children: [
          for (var index = 0; index < row.cells.length; index += 1)
            Expanded(
              flex: _columnFlex(index),
              child: _GuideCell(
                text: row.cells[index],
                emphasized: row.isHeader,
                pointsColumn: _isPointsColumn(index),
                lastColumn: index == row.cells.length - 1,
              ),
            ),
        ],
      ),
    );
  }

  int _columnFlex(int index) {
    if (columnCount == 2) {
      return index == 0 ? 7 : 2;
    }
    if (columnCount >= 5) {
      return switch (index) {
        0 => 20,
        1 => 7,
        _ => 24,
      };
    }
    return 1;
  }

  bool _isPointsColumn(int index) {
    if (columnCount == 2) {
      return index == 1;
    }
    if (columnCount >= 5) {
      return index == 1;
    }
    return false;
  }
}

class _GuideCell extends StatelessWidget {
  const _GuideCell({
    required this.text,
    required this.emphasized,
    required this.pointsColumn,
    required this.lastColumn,
  });

  final String text;
  final bool emphasized;
  final bool pointsColumn;
  final bool lastColumn;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: lastColumn
            ? null
            : const Border(right: BorderSide(color: Color(0xFFD9DEE2))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Text(
          text,
          textAlign: pointsColumn ? TextAlign.center : TextAlign.left,
          softWrap: true,
          style: TextStyle(
            fontSize: 14.5,
            height: 1.25,
            fontWeight: emphasized || pointsColumn
                ? FontWeight.w700
                : FontWeight.w400,
            color: _textColor,
          ),
        ),
      ),
    );
  }

  Color get _textColor {
    if (pointsColumn) {
      return const Color(0xFF174B82);
    }
    return Colors.black;
  }
}

class _SubmissionText extends StatefulWidget {
  const _SubmissionText({required this.submission, super.key});

  final StudentSubmission submission;

  @override
  State<_SubmissionText> createState() => _SubmissionTextState();
}

class _SubmissionTextState extends State<_SubmissionText> {
  static final Map<String, double> _scrollOffsets = {};

  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController(
      initialScrollOffset: _scrollOffsets[widget.submission.alias] ?? 0.0,
    );
    _controller.addListener(_saveOffset);
  }

  void _saveOffset() {
    if (_controller.hasClients) {
      _scrollOffsets[widget.submission.alias] = _controller.offset;
    }
  }

  @override
  void dispose() {
    _saveOffset();
    _controller.removeListener(_saveOffset);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SingleChildScrollView(
        controller: _controller,
        padding: const EdgeInsets.all(20),
        child: SelectableText(
          widget.submission.content,
          style: const TextStyle(
            fontFamily: 'Consolas',
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _QuestionImage extends StatelessWidget {
  const _QuestionImage({required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: InteractiveViewer(
        minScale: 0.4,
        maxScale: 4,
        child: Center(
          child: Image.file(
            file,
            filterQuality: FilterQuality.medium,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _GuideStyle {
  const _GuideStyle._();

  static const title = TextStyle(
    fontSize: 27,
    height: 1.18,
    fontWeight: FontWeight.w800,
    color: Colors.black,
  );

  static const section = TextStyle(
    fontSize: 23,
    height: 1.22,
    fontWeight: FontWeight.w800,
    color: Color(0xFF2B73C2),
  );

  static const paragraph = TextStyle(fontSize: 15.5, height: 1.45);
}
