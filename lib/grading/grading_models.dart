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

class GradingGuide {
  const GradingGuide(this.blocks);

  const GradingGuide.empty() : blocks = const [];

  final List<DocumentBlock> blocks;
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
