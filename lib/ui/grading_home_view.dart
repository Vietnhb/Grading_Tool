import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../grading/grading_controller.dart';
import 'drop_package_panel.dart';
import 'grading_panel.dart';
import 'submission_viewer.dart';
import 'top_status_bar.dart';

class GradingHomeView extends ConsumerWidget {
  const GradingHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Doc state tu GradingController de biet da load package hay chua.
    // Neu chua co package -> DropPackagePanel; neu co -> _LoadedWorkspace.
    final hasPackage = ref.watch(
      gradingControllerProvider.select((state) => state.hasPackage),
    );
    final controller = ref.read(gradingControllerProvider.notifier);

    // Lang nghe loi tu controller. Khi package/docx/xlsx loi thi hien SnackBar.
    ref.listen(
      gradingControllerProvider.select((value) => value.errorMessage),
      (previous, next) {
        if (next == null || next == previous) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: controller.clearError,
            ),
          ),
        );
      },
    );

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowLeft, control: true):
            _PreviousIntent(),
        SingleActivator(LogicalKeyboardKey.arrowRight, control: true):
            _NextIntent(),
        SingleActivator(LogicalKeyboardKey.keyS, control: true): _SaveIntent(),
      },
      child: Actions(
        // Gan phim tat vao cac ham dieu huong/luu trong GradingController.
        actions: {
          _PreviousIntent: CallbackAction<_PreviousIntent>(
            onInvoke: (_) => _move(context, ref, controller.previousStudent),
          ),
          _NextIntent: CallbackAction<_NextIntent>(
            onInvoke: (_) => _move(context, ref, controller.nextStudent),
          ),
          _SaveIntent: CallbackAction<_SaveIntent>(
            onInvoke: (_) => controller.saveCurrent(),
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: hasPackage
                ? _LoadedWorkspace(
                    controller: controller,
                    onMove: (move) => _move(context, ref, move),
                  )
                : const _EmptyWorkspace(),
          ),
        ),
      ),
    );
  }

  Future<void> _move(
    BuildContext context,
    WidgetRef ref,
    Future<bool> Function() move,
  ) async {
    // Truoc khi doi sinh vien/marker: neu autosave tat va co sua chua luu,
    // hoi user co discard khong. Sau do moi goi ham move tiep theo.
    final state = ref.read(gradingControllerProvider);
    if (!state.autoSave && state.isDirty) {
      final discard = await _confirmDiscard(context);
      if (!discard) {
        return;
      }
      ref.read(gradingControllerProvider.notifier).discardCurrentChanges();
    }
    await move();
  }

  Future<bool> _confirmDiscard(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text(
          'Save manually or discard the current edits before switching students.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _EmptyWorkspace extends ConsumerWidget {
  const _EmptyWorkspace();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Man hinh dau tien: chon/keo tha folder. Callback tiep theo:
    // GradingController.loadPackage(path).
    final isLoading = ref.watch(
      gradingControllerProvider.select((state) => state.isLoading),
    );
    return DropPackagePanel(
      isLoading: isLoading,
      onPackageSelected: ref
          .read(gradingControllerProvider.notifier)
          .loadPackage,
    );
  }
}

class _LoadedWorkspace extends StatelessWidget {
  const _LoadedWorkspace({required this.controller, required this.onMove});

  final GradingController controller;
  final Future<void> Function(Future<bool> Function() move) onMove;

  @override
  Widget build(BuildContext context) {
    // Workspace sau khi load package: tren la status bar,
    // trai la danh sach sinh vien, giua la bai nop/rubric/de, phai la panel cham.
    return Column(
      children: [
        _StatusArea(controller: controller, onMove: onMove),
        Expanded(
          child: Row(
            children: [
              const Expanded(child: _SubmissionArea()),
              _GradingArea(controller: controller),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusArea extends ConsumerWidget {
  const _StatusArea({required this.controller, required this.onMove});

  final GradingController controller;
  final Future<void> Function(Future<bool> Function() move) onMove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Top bar lay thong tin tien do, marker filter va nut dieu huong.
    // Doi marker se goi controller.selectMarker(marker).
    final state = ref.watch(gradingControllerProvider);
    return TopStatusBar(
      currentIndex: state.currentIndex,
      gradedCount: state.gradedCount,
      totalStudents: state.totalStudents,
      markerOptions: state.markerOptions,
      selectedMarker: state.selectedMarker,
      packagePath: state.package?.rootDirectory.path ?? '',
      aiReady: state.aiReady,
      aiReadyLabel: state.aiReadyLabel,
      aiProviderStatus: _aiProviderStatus(state),
      onMarkerChanged: (marker) =>
          onMove(() => controller.selectMarker(marker)),
      onAiSettings: () => _showAiSettingsDialog(context, controller, state),
      onOpenPackage: controller.openPackageFolder,
      onFirst: () => onMove(() => controller.goToIndex(0)),
      onPrevious: () => onMove(controller.previousStudent),
      onNext: () => onMove(controller.nextStudent),
      onLast: () => onMove(
        () => controller.goToIndex(state.visibleSubmissions.length - 1),
      ),
    );
  }

  Future<void> _showAiSettingsDialog(
    BuildContext context,
    GradingController controller,
    GradingState state,
  ) async {
    final openRouterKeyController = TextEditingController();
    final openRouterModelController = TextEditingController(
      text: state.openRouterModel,
    );
    var obscure = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('AI Settings'),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.hub, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'OpenRouter',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (state.openRouterApiKeyConfigured)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Current key: ${state.openRouterApiKeyPreview}',
                        ),
                      ),
                    TextField(
                      controller: openRouterKeyController,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'OpenRouter API key',
                        hintText: state.openRouterApiKeyConfigured
                            ? 'Paste a new key to replace current key'
                            : 'sk-or-v1-...',
                        suffixIcon: IconButton(
                          tooltip: obscure ? 'Show key' : 'Hide key',
                          onPressed: () =>
                              setDialogState(() => obscure = !obscure),
                          icon: Icon(
                            obscure ? Icons.visibility : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: openRouterModelController,
                      decoration: const InputDecoration(
                        labelText: 'OpenRouter model',
                        hintText: 'openai/gpt-oss-120b:free',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (state.openRouterApiKeyConfigured)
                  TextButton(
                    onPressed: () async {
                      await controller.clearOpenRouterApiKey();
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text('Clear'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    await controller.saveAiSettings(
                      openRouterApiKey: openRouterKeyController.text.trim(),
                      openRouterModel: openRouterModelController.text.trim(),
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      openRouterKeyController.dispose();
      openRouterModelController.dispose();
    }
  }

  String _aiProviderStatus(GradingState state) {
    return state.openRouterApiKeyConfigured
        ? 'OpenRouter: ${state.openRouterModel} (${state.openRouterApiKeyPreview})'
        : 'Set OpenRouter API key';
  }
}

class _SubmissionArea extends ConsumerWidget {
  const _SubmissionArea();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Khu vuc xem bai: lay currentSubmission da parse tu SubmissionParser.
    // Neu null thi dang loading bai nop.
    final submission = ref.watch(
      gradingControllerProvider.select((state) => state.currentSubmission),
    );
    if (submission == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final questionImage = ref.watch(
      gradingControllerProvider.select(
        (state) => state.package!.questionImageFile,
      ),
    );
    final gradingGuide = ref.watch(
      gradingControllerProvider.select((state) => state.gradingGuide),
    );

    return SubmissionViewer(
      submission: submission,
      questionImage: questionImage,
      gradingGuide: gradingGuide,
    );
  }
}

class _GradingArea extends ConsumerWidget {
  const _GradingArea({required this.controller});

  final GradingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Panel cham diem ben phai. Moi thay doi diem/comment se day ve controller,
    // controller cap nhat GradingEntry va danh dau isDirty.
    final state = ref.watch(gradingControllerProvider);
    final submission = state.currentSubmission;
    final entry = state.currentEntry;
    if (submission == null || entry == null) {
      return const SizedBox.shrink();
    }

    return GradingPanel(
      entry: entry,
      autoSave: state.autoSave,
      isDirty: state.isDirty,
      isSaving: state.isSaving,
      isAiGrading: state.isAiGrading,
      rubricCriteria: state.rubricCriteria,
      criterionScores: state.currentCriterionScores,
      showMarker: state.selectedMarker.isNotEmpty,
      maxScores: state.gradingGuide.maxScores,
      onScoreChanged: controller.updateScore,
      onCriterionScoreChanged: controller.updateCriterionScore,
      onCommentChanged: controller.updateComment,
      onAutoSaveChanged: controller.setAutoSave,
      onAiSuggest: controller.suggestAiGrade,
      onSave: controller.saveCurrent,
    );
  }
}

class _PreviousIntent extends Intent {
  const _PreviousIntent();
}

class _NextIntent extends Intent {
  const _NextIntent();
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}
