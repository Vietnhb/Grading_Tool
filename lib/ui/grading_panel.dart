import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../grading/grading_models.dart';

class GradingPanel extends StatefulWidget {
  const GradingPanel({
    required this.entry,
    required this.autoSave,
    required this.isDirty,
    required this.isSaving,
    required this.onScoreChanged,
    required this.onCommentChanged,
    required this.onAutoSaveChanged,
    required this.onSave,
    this.showMarker = true,
    this.maxScores = const {},
    super.key,
  });

  final GradingEntry entry;
  final bool autoSave;
  final bool isDirty;
  final bool isSaving;
  final bool showMarker;
  final Map<int, int> maxScores;
  final void Function(int questionIndex, int? score) onScoreChanged;
  final ValueChanged<String> onCommentChanged;
  final ValueChanged<bool> onAutoSaveChanged;
  final VoidCallback onSave;

  @override
  State<GradingPanel> createState() => _GradingPanelState();
}

class _GradingPanelState extends State<GradingPanel> {
  late List<TextEditingController> _scoreControllers;
  late final TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    _scoreControllers = _controllersFor(widget.entry);
    _commentController = TextEditingController(text: widget.entry.comment);
  }

  @override
  void didUpdateWidget(covariant GradingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_questionCountChanged(oldWidget)) {
      _replaceScoreControllers();
      _commentController.text = widget.entry.comment;
      return;
    }

    if (oldWidget.entry.alias != widget.entry.alias) {
      _syncControllers();
    }
  }

  @override
  void dispose() {
    for (final controller in _scoreControllers) {
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
                  for (
                    var index = 0;
                    index < widget.entry.requestScores.length;
                    index += 1
                  )
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: _scoreControllers[index],
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          isDense: true,
                          labelText: 'Question ${index + 1}',
                          errorText: _hasScoreError(index) ? 'Max: ${widget.maxScores[index]}' : null,
                        ),
                        onChanged: (value) => widget.onScoreChanged(
                          index,
                          int.tryParse(value.trim()),
                        ),
                      ),
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
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          const Divider(height: 18),
          SizedBox(
            height: 44,
            child: FilledButton.icon(
              onPressed: widget.isSaving || !widget.isDirty || _hasAnyError()
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

  void _syncControllers() {
    for (var index = 0; index < _scoreControllers.length; index += 1) {
      _scoreControllers[index].text =
          widget.entry.requestScores[index]?.toString() ?? '';
    }
    _commentController.text = widget.entry.comment;
  }

  List<TextEditingController> _controllersFor(GradingEntry entry) {
    return entry.requestScores
        .map((score) => TextEditingController(text: score?.toString() ?? ''))
        .toList();
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
