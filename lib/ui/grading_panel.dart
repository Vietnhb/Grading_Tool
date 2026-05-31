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
    required this.onScoreChanged,
    required this.onCriterionScoreChanged,
    required this.onCommentChanged,
    required this.onAutoSaveChanged,
    required this.onAiSuggest,
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
  final bool showMarker;
  final Map<int, int> maxScores;
  final void Function(int questionIndex, int? score) onScoreChanged;
  final void Function(String criterionId, int? score) onCriterionScoreChanged;
  final ValueChanged<String> onCommentChanged;
  final ValueChanged<bool> onAutoSaveChanged;
  final VoidCallback onAiSuggest;
  final VoidCallback onSave;

  @override
  State<GradingPanel> createState() => _GradingPanelState();
}

class _GradingPanelState extends State<GradingPanel> {
  late List<TextEditingController> _scoreControllers;
  late Map<String, TextEditingController> _criterionControllers;
  late final TextEditingController _commentController;

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
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFF1A1C1C)),
                        ),
                      ),
                      const Text('Auto save', style: TextStyle(fontSize: 12, color: Color(0xFF6B7272), fontWeight: FontWeight.w500)),
                      const SizedBox(width: 4),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: widget.autoSave,
                          onChanged: widget.onAutoSaveChanged,
                          activeColor: const Color(0xFF2E7D7D),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (widget.showMarker) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F5F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF6B7272)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.entry.marker.isEmpty ? 'Unassigned' : widget.entry.marker,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFF4A5252), fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else
                    const SizedBox(height: 12),
                  if (widget.rubricCriteria.isEmpty)
                    _QuestionScoreFields(
                      controllers: _scoreControllers,
                      entry: widget.entry,
                      maxScores: widget.maxScores,
                      onScoreChanged: widget.onScoreChanged,
                    )
                  else
                    _CriterionScoreFields(
                      criteria: widget.rubricCriteria,
                      criterionScores: widget.criterionScores,
                      questionScores: widget.entry.requestScores,
                      controllers: _criterionControllers,
                      onCriterionScoreChanged: widget.onCriterionScoreChanged,
                    ),
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F3F1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Text('Total Score', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E4C4C), fontSize: 15)),
                        const Spacer(),
                        Text(
                          widget.entry.total.toString(),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF1E4C4C)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _commentController,
                    minLines: 4,
                    maxLines: 8,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFFAFCFC),
                      hintText: 'Add a comment...',
                      hintStyle: const TextStyle(color: Color(0xFFA0A7A7), fontSize: 14),
                      contentPadding: const EdgeInsets.all(14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE0E5E5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF2E7D7D), width: 1.5),
                      ),
                    ),
                    onChanged: widget.onCommentChanged,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: widget.isAiGrading ? null : widget.onAiSuggest,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2B73C2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: widget.isAiGrading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 20),
              label: Text(widget.isAiGrading ? 'AI grading...' : 'AI Suggest', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: widget.isSaving || !widget.isDirty || _hasAnyError()
                  ? null
                  : widget.onSave,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E4C4C),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE0E5E5),
                disabledForegroundColor: const Color(0xFF98A2A2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: widget.isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded, size: 20),
              label: Text(widget.isDirty ? 'Save Changes' : 'Saved', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
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
    for (var index = 0; index < _scoreControllers.length; index += 1) {
      _scoreControllers[index].text =
          widget.entry.requestScores[index]?.toString() ?? '';
    }
    _syncCriterionControllers();
    _commentController.text = widget.entry.comment;
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
                errorText: _hasScoreError(index) ? 'Max: ${maxScores[index]}' : null,
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0F5F5),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Question ${group.key + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2E7D7D), fontSize: 13),
                      ),
                      const Spacer(),
                      Text(
                        '${questionScores[group.key] ?? 0} / ${_maxFor(group.value)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E4C4C), fontSize: 13),
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
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF4A5252), height: 1.4, fontWeight: FontWeight.w500),
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
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1A1C1C)),
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: InputDecoration(
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.white,
                                    hintText: '/${criterion.maxScore}',
                                    hintStyle: const TextStyle(color: Color(0xFFB0B7B7)),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xFFE0E5E5)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xFF2E7D7D), width: 1.5),
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
