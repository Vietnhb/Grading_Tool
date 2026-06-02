import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../grading/ai_grading_service.dart';

class AliasScoreOverview {
  const AliasScoreOverview({
    required this.alias,
    required this.teacherTotal,
    required this.aiTotal,
  });

  final String alias;
  final int? teacherTotal;
  final int? aiTotal;

  int? get displayTotal => teacherTotal ?? aiTotal;
  String get sourceLabel => teacherTotal != null ? 'GV' : 'AI';
}

class SummarySection extends StatelessWidget {
  const SummarySection({
    required this.teacherTotal,
    required this.aiTotal,
    required this.teacherScores,
    required this.aiScores,
    required this.criteria,
    required this.teacherCriterionScores,
    required this.aiCriterionScores,
    required this.aliasScoreOverview,
    required this.isDirty,
    required this.packageContext,
    required this.isAiGrading,
    required this.isSaving,
    required this.aiBatchRemaining,
    required this.aiBatchTotal,
    required this.aiApplyRemaining,
    required this.onAiBatchSuggest,
    required this.onApplyAiBatch,
    super.key,
  });

  final int teacherTotal;
  final int? aiTotal;
  final List<int?> teacherScores;
  final List<int?>? aiScores;
  final List<AiRubricCriterion> criteria;
  final Map<String, int?> teacherCriterionScores;
  final Map<String, int?> aiCriterionScores;
  final List<AliasScoreOverview> aliasScoreOverview;
  final bool isDirty;
  final String packageContext;
  final bool isAiGrading;
  final bool isSaving;
  final int aiBatchRemaining;
  final int aiBatchTotal;
  final int aiApplyRemaining;
  final VoidCallback onAiBatchSuggest;
  final VoidCallback onApplyAiBatch;

  @override
  Widget build(BuildContext context) {
    final hasTeacherGrades =
        teacherScores.any((score) => score != null) ||
        teacherCriterionScores.values.any((score) => score != null);
    final hasAiGrades = aiTotal != null;
    final difference = hasTeacherGrades && hasAiGrades
        ? teacherTotal - aiTotal!
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScoreOverview(
          teacherTotal: teacherTotal,
          aiTotal: aiTotal,
          hasTeacherGrades: hasTeacherGrades,
        ),
        const SizedBox(height: 10),
        _BatchAiButton(
          isAiGrading: isAiGrading,
          remaining: aiBatchRemaining,
          total: aiBatchTotal,
          onPressed: onAiBatchSuggest,
        ),
        const SizedBox(height: 8),
        _ApplyAiBatchButton(
          isSaving: isSaving,
          isBlocked: isAiGrading,
          remaining: aiApplyRemaining,
          onPressed: onApplyAiBatch,
        ),
        const SizedBox(height: 10),
        _DifferenceStrip(difference: difference, hasAiGrades: hasAiGrades),
        const SizedBox(height: 10),
        _CriterionDifferenceList(
          criteria: criteria,
          teacherCriterionScores: teacherCriterionScores,
          aiCriterionScores: aiCriterionScores,
          teacherScores: teacherScores,
          aiScores: aiScores,
          hasAiGrades: hasAiGrades,
        ),
        const SizedBox(height: 10),
        _SaveStatusPill(isDirty: isDirty, hasTeacherGrades: hasTeacherGrades),
        const SizedBox(height: 10),
        _AliasScoreDashboard(items: aliasScoreOverview, maxScore: _maxTotal),
        const SizedBox(height: 10),
        _AiPromptPreview(packageContext: packageContext),
      ],
    );
  }

  int get _maxTotal {
    final total = criteria.fold(
      0,
      (sum, criterion) => sum + criterion.maxScore,
    );
    return total > 0 ? total : 100;
  }
}

class _ScoreOverview extends StatelessWidget {
  const _ScoreOverview({
    required this.teacherTotal,
    required this.aiTotal,
    required this.hasTeacherGrades,
  });

  final int teacherTotal;
  final int? aiTotal;
  final bool hasTeacherGrades;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ScoreTile(
            label: 'Giáo viên',
            value: hasTeacherGrades ? '$teacherTotal' : 'N/A',
            color: const Color(0xFFE8F3F1),
            borderColor: const Color(0xFFBEE0D8),
            valueColor: const Color(0xFF0F766E),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ScoreTile(
            label: 'AI',
            value: aiTotal?.toString() ?? 'N/A',
            color: const Color(0xFFEAF2FB),
            borderColor: const Color(0xFFC8DDF6),
            valueColor: const Color(0xFF2563C7),
          ),
        ),
      ],
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({
    required this.label,
    required this.value,
    required this.color,
    required this.borderColor,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color color;
  final Color borderColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF14504E),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 30,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AliasScoreDashboard extends StatelessWidget {
  const _AliasScoreDashboard({required this.items, required this.maxScore});

  final List<AliasScoreOverview> items;
  final int maxScore;

  @override
  Widget build(BuildContext context) {
    final lowLimit = (maxScore * 0.5).round();
    final highLimit = (maxScore * 0.85).round();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE0E6E6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(Icons.insights, size: 18, color: Color(0xFF2B7A78)),
                SizedBox(width: 8),
                Text(
                  'Tổng quan điểm',
                  style: TextStyle(
                    color: Color(0xFF174A4A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _ScoreStatePanel(
                      title: 'Giáo viên',
                      scores: [
                        for (final item in items)
                          if (item.teacherTotal != null)
                            _AliasScorePoint(item.alias, item.teacherTotal!),
                      ],
                      maxScore: maxScore,
                      lowLimit: lowLimit,
                      highLimit: highLimit,
                      accent: const Color(0xFF0F766E),
                      background: const Color(0xFFE8F3F1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ScoreStatePanel(
                      title: 'AI',
                      scores: [
                        for (final item in items)
                          if (item.aiTotal != null)
                            _AliasScorePoint(item.alias, item.aiTotal!),
                      ],
                      maxScore: maxScore,
                      lowLimit: lowLimit,
                      highLimit: highLimit,
                      accent: const Color(0xFF2563C7),
                      background: const Color(0xFFEAF2FB),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AliasScorePoint {
  const _AliasScorePoint(this.alias, this.score);

  final String alias;
  final int score;
}

class _ScoreStatePanel extends StatelessWidget {
  const _ScoreStatePanel({
    required this.title,
    required this.scores,
    required this.maxScore,
    required this.lowLimit,
    required this.highLimit,
    required this.accent,
    required this.background,
  });

  final String title;
  final List<_AliasScorePoint> scores;
  final int maxScore;
  final int lowLimit;
  final int highLimit;
  final Color accent;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final sortedLow = scores.where((item) => item.score <= lowLimit).toList()
      ..sort((a, b) => a.score.compareTo(b.score));
    final sortedHigh = scores.where((item) => item.score >= highLimit).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    final average = _average(scores.map((item) => item.score));

    return Container(
      constraints: const BoxConstraints(minHeight: 218),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE8EDED)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w900),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${scores.length}',
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StateAverageBar(
            average: average,
            maxScore: maxScore,
            accent: accent,
            background: background,
          ),
          const SizedBox(height: 12),
          _CompactAliasList(
            title: 'Point <= $lowLimit',
            emptyText: 'Không có',
            items: sortedLow,
            color: const Color(0xFFB42318),
          ),
          const SizedBox(height: 10),
          _CompactAliasList(
            title: 'Point >= $highLimit',
            emptyText: 'Không có',
            items: sortedHigh,
            color: const Color(0xFF0F766E),
          ),
        ],
      ),
    );
  }

  double? _average(Iterable<int> values) {
    final list = values.toList();
    if (list.isEmpty) {
      return null;
    }
    return list.fold<int>(0, (sum, value) => sum + value) / list.length;
  }
}

class _StateAverageBar extends StatelessWidget {
  const _StateAverageBar({
    required this.average,
    required this.maxScore,
    required this.accent,
    required this.background,
  });

  final double? average;
  final int maxScore;
  final Color accent;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final ratio = average == null || maxScore <= 0
        ? 0.0
        : (average! / maxScore).clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              average == null ? 'N/A' : _format(average!),
              style: TextStyle(
                color: accent,
                fontSize: 26,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '/ $maxScore TB',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF647171),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: ratio,
            backgroundColor: background,
            color: accent,
          ),
        ),
      ],
    );
  }

  String _format(double raw) {
    final rounded = raw.roundToDouble();
    return (raw - rounded).abs() < 0.05
        ? rounded.toInt().toString()
        : raw.toStringAsFixed(1);
  }
}

class _CompactAliasList extends StatelessWidget {
  const _CompactAliasList({
    required this.title,
    required this.emptyText,
    required this.items,
    required this.color,
  });

  final String title;
  final String emptyText;
  final List<_AliasScorePoint> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final groupedItems = _groupByScore(items);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE8EDED)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAFCFC),
                  border: Border(bottom: BorderSide(color: Color(0xFFE8EDED))),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Alias',
                        style: TextStyle(
                          color: Color(0xFF8A9696),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      'Point',
                      style: TextStyle(
                        color: Color(0xFF8A9696),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 176,
                child: groupedItems.isEmpty
                    ? Center(
                        child: Text(
                          emptyText,
                          style: const TextStyle(
                            color: Color(0xFF8A9696),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: groupedItems.length,
                        itemBuilder: (context, index) {
                          final item = groupedItems[index];
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              border: index == groupedItems.length - 1
                                  ? null
                                  : const Border(
                                      bottom: BorderSide(
                                        color: Color(0xFFE8EDED),
                                      ),
                                    ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.aliases.join(', '),
                                    style: const TextStyle(
                                      color: Color(0xFF4B5563),
                                      fontSize: 12,
                                      height: 1.35,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${item.score}',
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<_AliasScoreGroup> _groupByScore(List<_AliasScorePoint> rawItems) {
    final groups = <int, List<String>>{};
    for (final item in rawItems) {
      groups.putIfAbsent(item.score, () => []).add(item.alias);
    }
    return [
      for (final entry in groups.entries)
        _AliasScoreGroup(score: entry.key, aliases: entry.value),
    ];
  }
}

class _AliasScoreGroup {
  const _AliasScoreGroup({required this.score, required this.aliases});

  final int score;
  final List<String> aliases;
}

class _BatchAiButton extends StatelessWidget {
  const _BatchAiButton({
    required this.isAiGrading,
    required this.remaining,
    required this.total,
    required this.onPressed,
  });

  final bool isAiGrading;
  final int remaining;
  final int total;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = isAiGrading || remaining == 0;
    final done = total - remaining;
    final percent = total <= 0
        ? 0
        : ((done / total) * 100).clamp(0, 100).round();
    final label = isAiGrading
        ? 'AI đang chấm $percent%'
        : remaining == 0
        ? 'Tất cả đã có AI chấm'
        : 'Chấm AI hàng loạt ($remaining)';

    return FilledButton.icon(
      onPressed: disabled ? null : onPressed,
      icon: isAiGrading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.auto_awesome),
      label: Text(label),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _ApplyAiBatchButton extends StatelessWidget {
  const _ApplyAiBatchButton({
    required this.isSaving,
    required this.isBlocked,
    required this.remaining,
    required this.onPressed,
  });

  final bool isSaving;
  final bool isBlocked;
  final int remaining;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = isSaving || isBlocked || remaining == 0;
    final label = isSaving
        ? 'Đang apply...'
        : isBlocked
        ? 'Chờ AI chấm xong'
        : remaining == 0
        ? 'Không có AI để apply'
        : 'Apply AI vào giáo viên ($remaining)';

    return OutlinedButton.icon(
      onPressed: disabled ? null : onPressed,
      icon: isSaving
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.call_merge_rounded),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF0F766E),
        side: const BorderSide(color: Color(0xFF99D1CA)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _DifferenceStrip extends StatelessWidget {
  const _DifferenceStrip({required this.difference, required this.hasAiGrades});

  final int? difference;
  final bool hasAiGrades;

  @override
  Widget build(BuildContext context) {
    final text = difference == null
        ? hasAiGrades
              ? 'Chưa có điểm giáo viên'
              : 'Chưa có điểm AI'
        : difference == 0
        ? 'Giáo viên bằng AI'
        : difference! > 0
        ? 'Giáo viên cao hơn AI'
        : 'Giáo viên thấp hơn AI';
    final value = difference == null ? '' : difference!.abs().toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        border: Border.all(color: const Color(0xFFF8D8BD)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.compare_arrows, color: Color(0xFFB45309), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (value.isNotEmpty)
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFFB45309),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }
}

class _CriterionDifferenceList extends StatelessWidget {
  const _CriterionDifferenceList({
    required this.criteria,
    required this.teacherCriterionScores,
    required this.aiCriterionScores,
    required this.teacherScores,
    required this.aiScores,
    required this.hasAiGrades,
  });

  final List<AiRubricCriterion> criteria;
  final Map<String, int?> teacherCriterionScores;
  final Map<String, int?> aiCriterionScores;
  final List<int?> teacherScores;
  final List<int?>? aiScores;
  final bool hasAiGrades;

  @override
  Widget build(BuildContext context) {
    final rows = _rows();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE0E6E6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Icon(
                  Icons.format_list_numbered,
                  size: 18,
                  color: Color(0xFF2B7A78),
                ),
                SizedBox(width: 8),
                Text(
                  'Tiêu chí lệch điểm',
                  style: TextStyle(
                    color: Color(0xFF174A4A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8EDED)),
          if (!hasAiGrades)
            const _DifferenceNote(text: 'Chưa có AI chấm cho bài này.')
          else if (rows.isEmpty)
            const _DifferenceNote(text: 'Không có tiêu chí nào lệch điểm.')
          else
            for (final row in rows) _CriterionDifferenceRow(row: row),
        ],
      ),
    );
  }

  List<_CriterionDifference> _rows() {
    final rows = <_CriterionDifference>[];
    if (criteria.isNotEmpty) {
      for (final criterion in criteria) {
        final teacher = teacherCriterionScores[criterion.id];
        final ai = aiCriterionScores[criterion.id];
        if (teacher == null || ai == null || teacher == ai) {
          continue;
        }
        rows.add(
          _CriterionDifference(
            label: criterion.id,
            title: criterion.title,
            teacherScore: teacher,
            aiScore: ai,
          ),
        );
      }
      return rows;
    }

    final ai = aiScores;
    if (ai == null) {
      return rows;
    }
    final count = teacherScores.length < ai.length
        ? teacherScores.length
        : ai.length;
    for (var i = 0; i < count; i += 1) {
      final teacher = teacherScores[i];
      final aiScore = ai[i];
      if (teacher == null || aiScore == null || teacher == aiScore) {
        continue;
      }
      rows.add(
        _CriterionDifference(
          label: 'Câu ${i + 1}',
          title: '',
          teacherScore: teacher,
          aiScore: aiScore,
        ),
      );
    }
    return rows;
  }
}

class _CriterionDifference {
  const _CriterionDifference({
    required this.label,
    required this.title,
    required this.teacherScore,
    required this.aiScore,
  });

  final String label;
  final String title;
  final int teacherScore;
  final int aiScore;
}

class _CriterionDifferenceRow extends StatelessWidget {
  const _CriterionDifferenceRow({required this.row});

  final _CriterionDifference row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 48),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3EA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              row.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFB45309),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              row.title.isEmpty ? row.label : row.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF4B5563),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'GV ${row.teacherScore} / AI ${row.aiScore}',
            style: const TextStyle(
              color: Color(0xFFB45309),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DifferenceNote extends StatelessWidget {
  const _DifferenceNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF6B7272),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SaveStatusPill extends StatelessWidget {
  const _SaveStatusPill({
    required this.isDirty,
    required this.hasTeacherGrades,
  });

  final bool isDirty;
  final bool hasTeacherGrades;

  @override
  Widget build(BuildContext context) {
    final hasSavedGrade = hasTeacherGrades && !isDirty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: hasSavedGrade
            ? const Color(0xFFE8F3F1)
            : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            hasSavedGrade ? Icons.check_circle : Icons.warning_amber,
            size: 18,
            color: hasSavedGrade
                ? const Color(0xFF0F766E)
                : const Color(0xFFB45309),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              !hasTeacherGrades
                  ? 'Chưa có điểm giáo viên.'
                  : isDirty
                  ? 'Chưa lưu điểm giáo viên.'
                  : 'Điểm giáo viên đã lưu.',
              style: TextStyle(
                color: hasSavedGrade
                    ? const Color(0xFF0F766E)
                    : const Color(0xFF92400E),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiPromptPreview extends StatelessWidget {
  const _AiPromptPreview({required this.packageContext});

  final String packageContext;

  @override
  Widget build(BuildContext context) {
    final length = packageContext.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE0E6E6)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.article, color: Color(0xFF2B7A78), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prompt gửi AI',
                  style: TextStyle(
                    color: Color(0xFF174A4A),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$length ký tự context',
                  style: const TextStyle(
                    color: Color(0xFF6B7272),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'Sao chép',
            child: IconButton(
              onPressed: packageContext.isEmpty
                  ? null
                  : () =>
                        Clipboard.setData(ClipboardData(text: packageContext)),
              icon: const Icon(Icons.copy, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
