import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../grading/ai_grading_service.dart';
import '../grading/grading_models.dart';

class GradingPanel extends StatefulWidget {
  const GradingPanel({
    required this.entry,
    required this.autoSave,
    required this.isDirty,
    required this.isSaving,
    required this.isAiGrading,
    required this.rubricCriteria,
    required this.criterionScores,
    required this.aiSuggestion,
    required this.onScoreChanged,
    required this.onCriterionScoreChanged,
    required this.onCommentChanged,
    required this.onAutoSaveChanged,
    required this.onAiSuggest,
    required this.onApplyAiSuggestion,
    required this.onSave,
    this.showMarker = true,
    this.maxScores = const {},
    super.key,
  });

  final GradingEntry entry;
  final bool autoSave;
  final bool isDirty;
  final bool isSaving;
  final bool isAiGrading;
  final List<AiRubricCriterion> rubricCriteria;
  final Map<String, int?> criterionScores;
  final AiGradeSuggestion? aiSuggestion;
  final bool showMarker;
  final Map<int, int> maxScores;
  final void Function(int questionIndex, int? score) onScoreChanged;
  final void Function(String criterionId, int? score) onCriterionScoreChanged;
  final ValueChanged<String> onCommentChanged;
  final ValueChanged<bool> onAutoSaveChanged;
  final VoidCallback onAiSuggest;
  final VoidCallback onApplyAiSuggestion;
  final VoidCallback onSave;

  @override
  State<GradingPanel> createState() => _GradingPanelState();
}

enum _GradingPanelMode { summary, teacher, ai }

class _GradingPanelState extends State<GradingPanel> {
  late List<TextEditingController> _scoreControllers;
  late Map<String, TextEditingController> _criterionControllers;
  late final TextEditingController _commentController;
  _GradingPanelMode _mode = _GradingPanelMode.summary;

  @override
  void initState() {
    super.initState();
    _scoreControllers = _controllersFor(widget.entry);
    _criterionControllers = _criterionControllersFor(widget.criterionScores);
    _commentController = TextEditingController(text: widget.entry.comment);
  }

  @override
  void didUpdateWidget(covariant GradingPanel oldWidget) {
    // Khi doi sinh vien hoac so cau thay doi, sync lai TextEditingController
    // de textbox hien dung diem/comment cua entry moi.
    super.didUpdateWidget(oldWidget);
    if (_questionCountChanged(oldWidget)) {
      _replaceScoreControllers();
      _replaceCriterionControllers();
      _commentController.text = widget.entry.comment;
      return;
    }

    if (oldWidget.entry.alias != widget.entry.alias) {
      _syncControllers();
    }
    if (oldWidget.entry.requestScores != widget.entry.requestScores) {
      _syncScoreControllers();
    }
    if (oldWidget.entry.comment != widget.entry.comment &&
        _commentController.text != widget.entry.comment) {
      _commentController.text = widget.entry.comment;
    }
    if (oldWidget.criterionScores != widget.criterionScores ||
        oldWidget.rubricCriteria.length != widget.rubricCriteria.length) {
      _syncCriterionControllers();
    }
  }

  @override
  void dispose() {
    for (final controller in _scoreControllers) {
      controller.dispose();
    }
    for (final controller in _criterionControllers.values) {
      controller.dispose();
    }
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Color(0xFFE0E5E5))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              key: PageStorageKey('grading-panel-scroll-${widget.entry.alias}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Alias ${widget.entry.alias}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1A1C1C),
                              ),
                        ),
                      ),
                      const Text(
                        'Auto save',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7272),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: widget.autoSave,
                          onChanged: widget.onAutoSaveChanged,
                          activeThumbColor: const Color(0xFF2E7D7D),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (widget.showMarker) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F5F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.person_outline_rounded,
                            size: 16,
                            color: Color(0xFF6B7272),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.entry.marker.isEmpty
                                  ? 'Unassigned'
                                  : widget.entry.marker,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF4A5252),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else
                    const SizedBox(height: 12),
                  _GradingModeTabs(
                    selected: _mode,
                    onChanged: (mode) => setState(() => _mode = mode),
                  ),
                  const SizedBox(height: 14),
                  _selectedModeView(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectedModeView() {
    return switch (_mode) {
      _GradingPanelMode.summary => _SummarySection(
        teacherTotal: widget.entry.total,
        aiTotal: widget.aiSuggestion?.total,
        isDirty: widget.isDirty,
      ),
      _GradingPanelMode.teacher => _TeacherGradingSection(
        entry: widget.entry,
        rubricCriteria: widget.rubricCriteria,
        criterionScores: widget.criterionScores,
        maxScores: widget.maxScores,
        scoreControllers: _scoreControllers,
        criterionControllers: _criterionControllers,
        commentController: _commentController,
        onScoreChanged: widget.onScoreChanged,
        onCriterionScoreChanged: widget.onCriterionScoreChanged,
        onCommentChanged: widget.onCommentChanged,
        isSaving: widget.isSaving,
        isDirty: widget.isDirty,
        hasAnyError: _hasAnyError(),
        onSave: widget.onSave,
      ),
      _GradingPanelMode.ai => _AiGradingSection(
        suggestion: widget.aiSuggestion,
        criteria: widget.rubricCriteria,
        isAiGrading: widget.isAiGrading,
        onAiSuggest: widget.onAiSuggest,
        onApply: widget.onApplyAiSuggestion,
      ),
    };
  }

  bool _questionCountChanged(GradingPanel oldWidget) {
    return oldWidget.entry.requestScores.length !=
        widget.entry.requestScores.length;
  }

  void _replaceScoreControllers() {
    for (final controller in _scoreControllers) {
      controller.dispose();
    }
    _scoreControllers = _controllersFor(widget.entry);
  }

  void _replaceCriterionControllers() {
    for (final controller in _criterionControllers.values) {
      controller.dispose();
    }
    _criterionControllers = _criterionControllersFor(widget.criterionScores);
  }

  void _syncControllers() {
    _syncScoreControllers();
    _syncCriterionControllers();
    _commentController.text = widget.entry.comment;
  }

  void _syncScoreControllers() {
    for (var index = 0; index < _scoreControllers.length; index += 1) {
      _scoreControllers[index].text =
          widget.entry.requestScores[index]?.toString() ?? '';
    }
  }

  void _syncCriterionControllers() {
    for (final criterion in widget.rubricCriteria) {
      final controller = _criterionControllers.putIfAbsent(
        criterion.id,
        () => TextEditingController(),
      );
      final value = widget.criterionScores[criterion.id]?.toString() ?? '';
      if (controller.text != value) {
        controller.text = value;
      }
    }
  }

  List<TextEditingController> _controllersFor(GradingEntry entry) {
    return entry.requestScores
        .map((score) => TextEditingController(text: score?.toString() ?? ''))
        .toList();
  }

  Map<String, TextEditingController> _criterionControllersFor(
    Map<String, int?> scores,
  ) {
    return {
      for (final criterion in widget.rubricCriteria)
        criterion.id: TextEditingController(
          text: scores[criterion.id]?.toString() ?? '',
        ),
    };
  }

  bool _hasScoreError(int index) {
    final score = widget.entry.requestScores[index];
    final maxScore = widget.maxScores[index];
    return score != null && maxScore != null && score > maxScore;
  }

  bool _hasAnyError() {
    for (var i = 0; i < widget.entry.requestScores.length; i++) {
      if (_hasScoreError(i)) return true;
    }
    return false;
  }
}

class _GradingModeTabs extends StatelessWidget {
  const _GradingModeTabs({
    required this.selected,
    required this.onChanged,
  });

  final _GradingPanelMode selected;
  final ValueChanged<_GradingPanelMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _ModeButton(
            label: 'Tổng hợp',
            icon: Icons.summarize_rounded,
            selected: selected == _GradingPanelMode.summary,
            onPressed: () => onChanged(_GradingPanelMode.summary),
          ),
          _ModeButton(
            label: 'Giáo viên',
            icon: Icons.edit_note_rounded,
            selected: selected == _GradingPanelMode.teacher,
            onPressed: () => onChanged(_GradingPanelMode.teacher),
          ),
          _ModeButton(
            label: 'AI chấm',
            icon: Icons.auto_awesome_rounded,
            selected: selected == _GradingPanelMode.ai,
            onPressed: () => onChanged(_GradingPanelMode.ai),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: TextButton.icon(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: selected
                ? const Color(0xFF1E4C4C)
                : const Color(0xFF6B7272),
            backgroundColor: selected ? Colors.white : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          icon: Icon(icon, size: 16),
          label: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _TeacherGradingSection extends StatelessWidget {
  const _TeacherGradingSection({
    required this.entry,
    required this.rubricCriteria,
    required this.criterionScores,
    required this.maxScores,
    required this.scoreControllers,
    required this.criterionControllers,
    required this.commentController,
    required this.onScoreChanged,
    required this.onCriterionScoreChanged,
    required this.onCommentChanged,
    required this.isSaving,
    required this.isDirty,
    required this.hasAnyError,
    required this.onSave,
  });

  final GradingEntry entry;
  final List<AiRubricCriterion> rubricCriteria;
  final Map<String, int?> criterionScores;
  final Map<int, int> maxScores;
  final List<TextEditingController> scoreControllers;
  final Map<String, TextEditingController> criterionControllers;
  final TextEditingController commentController;
  final void Function(int questionIndex, int? score) onScoreChanged;
  final void Function(String criterionId, int? score) onCriterionScoreChanged;
  final ValueChanged<String> onCommentChanged;
  final bool isSaving;
  final bool isDirty;
  final bool hasAnyError;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rubricCriteria.isEmpty)
          _QuestionScoreFields(
            controllers: scoreControllers,
            entry: entry,
            maxScores: maxScores,
            onScoreChanged: onScoreChanged,
          )
        else
          _CriterionScoreFields(
            criteria: rubricCriteria,
            criterionScores: criterionScores,
            questionScores: entry.requestScores,
            controllers: criterionControllers,
            onCriterionScoreChanged: onCriterionScoreChanged,
          ),
        const SizedBox(height: 12),
        _TotalRow(
          label: 'Teacher Total',
          value: entry.total.toString(),
          color: const Color(0xFFE8F3F1),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: commentController,
          minLines: 4,
          maxLines: 8,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFFAFCFC),
            hintText: 'Add a teacher comment...',
            hintStyle: const TextStyle(
              color: Color(0xFFA0A7A7),
              fontSize: 14,
            ),
            contentPadding: const EdgeInsets.all(14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE0E5E5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFF2E7D7D),
                width: 1.5,
              ),
            ),
          ),
          onChanged: onCommentChanged,
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: isSaving || !isDirty || hasAnyError ? null : onSave,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1E4C4C),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFE0E5E5),
              disabledForegroundColor: const Color(0xFF98A2A2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            icon: isSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded, size: 20),
            label: Text(
              isDirty ? 'Save teacher grade' : 'Teacher grade saved',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AiGradingSection extends StatelessWidget {
  const _AiGradingSection({
    required this.suggestion,
    required this.criteria,
    required this.isAiGrading,
    required this.onAiSuggest,
    required this.onApply,
  });

  final AiGradeSuggestion? suggestion;
  final List<AiRubricCriterion> criteria;
  final bool isAiGrading;
  final VoidCallback onAiSuggest;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final currentSuggestion = suggestion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 42,
          child: FilledButton.icon(
            onPressed: isAiGrading ? null : onAiSuggest,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2B73C2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            icon: isAiGrading
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text(isAiGrading ? 'AI grading...' : 'Run AI grading'),
          ),
        ),
        const SizedBox(height: 12),
        if (currentSuggestion == null)
          const Text(
            'No AI suggestion for this alias yet.',
            style: TextStyle(color: Color(0xFF6B7272), fontSize: 13),
          )
        else ...[
          _TotalRow(
            label: 'AI Total',
            value: currentSuggestion.total.toString(),
            color: const Color(0xFFEAF2FB),
          ),
          const SizedBox(height: 10),
          _AiRequestScores(
            criteria: criteria,
            suggestion: currentSuggestion,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onApply,
            icon: const Icon(Icons.call_merge_rounded, size: 18),
            label: const Text('Apply to teacher grade'),
          ),
        ],
      ],
    );
  }
}

class _AiRequestScores extends StatelessWidget {
  const _AiRequestScores({
    required this.criteria,
    required this.suggestion,
  });

  final List<AiRubricCriterion> criteria;
  final AiGradeSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final groups = <int, List<AiRubricCriterion>>{};
    for (final criterion in criteria) {
      groups.putIfAbsent(criterion.questionIndex, () => []).add(criterion);
    }
    final sortedGroups = groups.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in sortedGroups) aiRequestCard(group: group),
      ],
    );
  }

  Widget aiRequestCard({required MapEntry<int, List<AiRubricCriterion>> group}) {
    final requestComment = _requestComment(group.value);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFCFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Request ${group.key + 1}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2E7D7D),
                  ),
                ),
              ),
              Text(
                '${_groupScore(group.value)} / ${_groupMax(group.value)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E4C4C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final criterion in group.value) aiCriterionComment(criterion),
          if (requestComment.isNotEmpty) ...[
            const Divider(height: 14, color: Color(0xFFE0E5E5)),
            SelectableText(
              requestComment,
              style: const TextStyle(
                color: Color(0xFF4A5252),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget aiCriterionComment(AiRubricCriterion criterion) {
    final comment = _commentFor(criterion);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${criterion.id} ${criterion.title}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4A5252),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${suggestion.criterionScores[criterion.id] ?? 0}/${criterion.maxScore}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E4C4C),
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: SelectableText(
                comment,
                style: const TextStyle(
                  color: Color(0xFF6B7272),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  int _groupScore(List<AiRubricCriterion> criteria) {
    return criteria.fold(
      0,
      (sum, criterion) => sum + (suggestion.criterionScores[criterion.id] ?? 0),
    );
  }

  int _groupMax(List<AiRubricCriterion> criteria) {
    return criteria.fold(0, (sum, criterion) => sum + criterion.maxScore);
  }

  String _commentFor(AiRubricCriterion criterion) {
    return suggestion.comments[criterion.id]?.trim() ?? '';
  }

  String _requestComment(List<AiRubricCriterion> criteria) {
    return [
      for (final criterion in criteria)
        if (_commentFor(criterion).isNotEmpty)
          '${criterion.id}: ${_commentFor(criterion)}',
    ].join('\n');
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.teacherTotal,
    required this.aiTotal,
    required this.isDirty,
  });

  final int teacherTotal;
  final int? aiTotal;
  final bool isDirty;

  @override
  Widget build(BuildContext context) {
    final difference = aiTotal == null ? null : teacherTotal - aiTotal!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TotalRow(
          label: 'Teacher Total',
          value: teacherTotal.toString(),
          color: const Color(0xFFE8F3F1),
        ),
        const SizedBox(height: 8),
        _TotalRow(
          label: 'AI Total',
          value: aiTotal?.toString() ?? 'Not run',
          color: const Color(0xFFEAF2FB),
        ),
        const SizedBox(height: 8),
        _TotalRow(
          label: 'Teacher - AI',
          value: difference == null
              ? 'N/A'
              : difference > 0
              ? '+$difference'
              : difference.toString(),
          color: const Color(0xFFF6F7F7),
        ),
        const SizedBox(height: 8),
        Text(
          isDirty ? 'Teacher grade has unsaved changes.' : 'Teacher grade is saved.',
          style: const TextStyle(
            color: Color(0xFF6B7272),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E4C4C),
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Color(0xFF1E4C4C),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionScoreFields extends StatelessWidget {
  const _QuestionScoreFields({
    required this.controllers,
    required this.entry,
    required this.maxScores,
    required this.onScoreChanged,
  });

  final List<TextEditingController> controllers;
  final GradingEntry entry;
  final Map<int, int> maxScores;
  final void Function(int questionIndex, int? score) onScoreChanged;

  bool _hasScoreError(int index) {
    final score = entry.requestScores[index];
    final maxScore = maxScores[index];
    return score != null && maxScore != null && score > maxScore;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < entry.requestScores.length; index += 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: controllers[index],
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Question ${index + 1}',
                errorText: _hasScoreError(index)
                    ? 'Max: ${maxScores[index]}'
                    : null,
              ),
              onChanged: (value) =>
                  onScoreChanged(index, int.tryParse(value.trim())),
            ),
          ),
      ],
    );
  }
}

class _CriterionScoreFields extends StatelessWidget {
  const _CriterionScoreFields({
    required this.criteria,
    required this.criterionScores,
    required this.questionScores,
    required this.controllers,
    required this.onCriterionScoreChanged,
  });

  final List<AiRubricCriterion> criteria;
  final Map<String, int?> criterionScores;
  final List<int?> questionScores;
  final Map<String, TextEditingController> controllers;
  final void Function(String criterionId, int? score) onCriterionScoreChanged;

  @override
  Widget build(BuildContext context) {
    final groups = <int, List<AiRubricCriterion>>{};
    for (final criterion in criteria) {
      groups.putIfAbsent(criterion.questionIndex, () => []).add(criterion);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups.entries)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFCFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEFF2F2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0F5F5),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(11),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Question ${group.key + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2E7D7D),
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${questionScores[group.key] ?? 0} / ${_maxFor(group.value)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E4C4C),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  child: Column(
                    children: [
                      for (final criterion in group.value)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '${criterion.id} ${criterion.title}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF4A5252),
                                      height: 1.4,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 68,
                                child: TextField(
                                  controller: controllers[criterion.id],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Color(0xFF1A1C1C),
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: InputDecoration(
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.white,
                                    hintText: '/${criterion.maxScore}',
                                    hintStyle: const TextStyle(
                                      color: Color(0xFFB0B7B7),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                      horizontal: 8,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE0E5E5),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF2E7D7D),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  onChanged: (value) => onCriterionScoreChanged(
                                    criterion.id,
                                    int.tryParse(value.trim()),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  int _maxFor(List<AiRubricCriterion> criteria) =>
      criteria.fold(0, (sum, criterion) => sum + criterion.maxScore);
}
