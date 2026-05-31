class GradingEntry {
  const GradingEntry({
    required this.alias,
    required this.marker,
    required this.requestScores,
    required this.comment,
  });

  factory GradingEntry.empty(String alias, {required int questionCount}) {
    return GradingEntry(
      alias: alias,
      marker: '',
      requestScores: List.filled(questionCount, null),
      comment: '',
    );
  }

  final String alias;
  final String marker;
  final List<int?> requestScores;
  final String comment;

  int get total => requestScores.fold(0, (sum, score) => sum + (score ?? 0));

  bool get isComplete => requestScores.every((score) => score != null);

  GradingEntry copyWith({
    String? marker,
    List<int?>? requestScores,
    String? comment,
  }) {
    return GradingEntry(
      alias: alias,
      marker: marker ?? this.marker,
      requestScores: requestScores ?? this.requestScores,
      comment: comment ?? this.comment,
    );
  }
}

class AiGradeSuggestion {
  const AiGradeSuggestion({
    required this.questionScores,
    required this.criterionScores,
    required this.comments,
    this.warnings = const [],
  });

  final List<int?> questionScores;
  final Map<String, int?> criterionScores;
  final Map<String, String> comments;
  final List<String> warnings;

  int get total => questionScores.fold(0, (sum, score) => sum + (score ?? 0));

  String get combinedComment {
    final lines = <String>[
      for (final entry in comments.entries)
        if (entry.value.trim().isNotEmpty) '${entry.key}: ${entry.value.trim()}',
      if (warnings.isNotEmpty) '',
      if (warnings.isNotEmpty) 'AI audit warnings:',
      for (final warning in warnings) '- $warning',
    ];
    return lines.join('\n');
  }
}

class GradingGuide {
  const GradingGuide(
    this.blocks, {
    this.maxScores = const {},
    this.questions = const [],
  });

  const GradingGuide.empty()
      : blocks = const [],
        maxScores = const {},
        questions = const [];

  final List<DocumentBlock> blocks;
  final Map<int, int> maxScores;
  final List<ExamQuestion> questions;
}

class ExamQuestion {
  const ExamQuestion({
    required this.number,
    required this.title,
    required this.content,
  });

  final int number;
  final String title;
  final String content;
}

sealed class DocumentBlock {
  const DocumentBlock();
}

class SectionBlock extends DocumentBlock {
  const SectionBlock({required this.heading, this.children = const []});

  final HeadingBlock heading;
  final List<DocumentBlock> children;
}

class HeadingBlock {
  const HeadingBlock({required this.text, required this.level, this.styleId});

  final String text;
  final int level;
  final String? styleId;
}

class ParagraphBlock extends DocumentBlock {
  const ParagraphBlock({required this.text, this.styleId});

  final String text;
  final String? styleId;
}

class BulletListBlock extends DocumentBlock {
  const BulletListBlock({required this.items, this.numberingId});

  final List<BulletListItemBlock> items;
  final String? numberingId;
}

class BulletListItemBlock {
  const BulletListItemBlock({
    required this.text,
    required this.level,
    this.numberingId,
  });

  final String text;
  final int level;
  final String? numberingId;
}

class RubricTableBlock extends DocumentBlock {
  const RubricTableBlock({required this.rows});

  final List<RubricTableRowBlock> rows;
}

class RubricTableRowBlock {
  const RubricTableRowBlock({required this.cells, this.isHeader = false});

  final List<String> cells;
  final bool isHeader;
}
