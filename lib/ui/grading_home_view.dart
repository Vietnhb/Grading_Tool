import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../grading/grading_controller.dart';
import '../core/file_name_utils.dart';
import 'drop_package_panel.dart';
import 'grading_panel.dart';
import 'student_sidebar.dart';
import 'submission_viewer.dart';
import 'top_status_bar.dart';

class GradingHomeView extends ConsumerWidget {
  const GradingHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPackage = ref.watch(
      gradingControllerProvider.select((state) => state.hasPackage),
    );
    final controller = ref.read(gradingControllerProvider.notifier);

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
                    onSelectStudent: (index) =>
                        _move(context, ref, () => controller.goToIndex(index)),
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
  const _LoadedWorkspace({
    required this.controller,
    required this.onMove,
    required this.onSelectStudent,
  });

  final GradingController controller;
  final Future<void> Function(Future<bool> Function() move) onMove;
  final ValueChanged<int> onSelectStudent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StatusArea(controller: controller, onMove: onMove),
        Expanded(
          child: Row(
            children: [
              _StudentListArea(onSelectStudent: onSelectStudent),
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
    final state = ref.watch(gradingControllerProvider);
    return TopStatusBar(
      gradedCount: state.gradedCount,
      totalStudents: state.totalStudents,
      markerOptions: state.markerOptions,
      selectedMarker: state.selectedMarker,
      packagePath: state.package?.rootDirectory.path ?? '',
      onMarkerChanged: (marker) =>
          onMove(() => controller.selectMarker(marker)),
      onOpenPackage: controller.openPackageFolder,
      onPrevious: () => onMove(controller.previousStudent),
      onNext: () => onMove(controller.nextStudent),
    );
  }
}

class _StudentListArea extends ConsumerWidget {
  const _StudentListArea({required this.onSelectStudent});

  final ValueChanged<int> onSelectStudent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gradingControllerProvider);
    final visibleSubmissions = state.visibleSubmissions;
    final aliases = visibleSubmissions.map(aliasFromFile).toList();
    final aliasSet = aliases.toSet();
    final gradedAliases = state.entries.values
        .where((entry) => aliasSet.contains(entry.alias))
        .where((entry) => entry.isComplete)
        .map((entry) => entry.alias)
        .toSet();

    return StudentSidebar(
      aliases: aliases,
      currentIndex: state.currentIndex,
      gradedAliases: gradedAliases,
      onSelect: onSelectStudent,
    );
  }
}

class _SubmissionArea extends ConsumerWidget {
  const _SubmissionArea();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      showMarker: state.selectedMarker.isNotEmpty,
      maxScores: state.gradingGuide.maxScores,
      onScoreChanged: controller.updateScore,
      onCommentChanged: controller.updateComment,
      onAutoSaveChanged: controller.setAutoSave,
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
