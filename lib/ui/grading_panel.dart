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
                  Text(
                    'Alias ${widget.entry.alias}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('Auto save'),
                      const Spacer(),
                      Switch(
                        value: widget.autoSave,
                        onChanged: widget.onAutoSaveChanged,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (widget.showMarker) ...[
                    InputDecorator(
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Assigned marker',
                      ),
                      child: Text(
                        widget.entry.marker.isEmpty ? '-' : widget.entry.marker,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Divider(height: 24),
                  ] else
                    const Divider(height: 24),
                  if (widget.rubricCriteria.isEmpty)
                    _QuestionScoreFields(
                      controllers: _scoreControllers,
                      entry: widget.entry,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    color: const Color(0xFFF1F4F4),
                    child: Row(
                      children: [
                        const Text('Total'),
                        const Spacer(),
                        Text(
                          widget.entry.total.toString(),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _commentController,
                    minLines: 5,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Comment',
                    ),
                    onChanged: widget.onCommentChanged,
                    // Comment thay doi -> GradingController.updateComment.
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          const Divider(height: 18),
          SizedBox(
            height: 40,
            child: OutlinedButton.icon(
              onPressed: widget.isAiGrading ? null : widget.onAiSuggest,
              icon: widget.isAiGrading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(widget.isAiGrading ? 'AI grading...' : 'AI Suggest'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: FilledButton.icon(
              onPressed: widget.isSaving || !widget.isDirty
                  ? null
                  : widget.onSave,
              icon: widget.isSaving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(widget.isDirty ? 'Save' : 'Saved'),
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
}

class _QuestionScoreFields extends StatelessWidget {
  const _QuestionScoreFields({
    required this.controllers,
    required this.entry,
    required this.onScoreChanged,
  });

  final List<TextEditingController> controllers;
  final GradingEntry entry;
  final void Function(int questionIndex, int? score) onScoreChanged;

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
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD8DEDE)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Question ${group.key + 1}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const Spacer(),
                        Text(
                          '${questionScores[group.key] ?? 0}/${_maxFor(group.value)}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final criterion in group.value)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 7),
                                child: Text(
                                  '${criterion.id} ${criterion.title}',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 72,
                              child: TextField(
                                controller: controllers[criterion.id],
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  isDense: true,
                                  labelText: '/${criterion.maxScore}',
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
            ),
          ),
      ],
    );
  }

  int _maxFor(List<AiRubricCriterion> criteria) =>
      criteria.fold(0, (sum, criterion) => sum + criterion.maxScore);
}
