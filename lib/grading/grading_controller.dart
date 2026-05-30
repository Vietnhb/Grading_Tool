import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_exception.dart';
import '../submission/submission_models.dart';
import 'grading_models.dart';
import '../document/docx_parser.dart';
import 'excel_grade_repository.dart';
import '../submission/package_detector.dart';
import '../submission/submission_parser.dart';
import '../core/file_name_utils.dart';

final gradingControllerProvider =
    NotifierProvider<GradingController, GradingState>(GradingController.new);

class GradingState {
  const GradingState({
    this.package,
    this.submissions = const [],
    this.entries = const {},
    this.markerOptions = const [],
    this.selectedMarker = '',
    this.gradingGuide = const GradingGuide.empty(),
    this.currentIndex = 0,
    this.currentSubmission,
    this.isLoading = false,
    this.isSaving = false,
    this.autoSave = true,
    this.isDirty = false,
    this.errorMessage,
    this.statusMessage = 'Drop an exam package folder to begin.',
  });

  final ExamPackage? package;
  final List<File> submissions;
  final Map<String, GradingEntry> entries;
  final List<String> markerOptions;
  final String selectedMarker;
  final GradingGuide gradingGuide;
  final int currentIndex;
  final StudentSubmission? currentSubmission;
  final bool isLoading;
  final bool isSaving;
  final bool autoSave;
  final bool isDirty;
  final String? errorMessage;
  final String statusMessage;

  GradingEntry? get currentEntry =>
      currentSubmission == null ? null : entries[currentSubmission!.alias];

  List<File> get visibleSubmissions {
    if (selectedMarker.isEmpty) {
      return submissions;
    }
    return submissions.where((file) {
      final alias = aliasFromFile(file);
      return entries[alias]?.marker == selectedMarker;
    }).toList();
  }

  int get gradedCount {
    final visibleAliases = visibleSubmissions.map(aliasFromFile).toSet();
    return entries.values
        .where((entry) => visibleAliases.contains(entry.alias))
        .where((entry) => entry.isComplete)
        .length;
  }

  int get totalStudents => visibleSubmissions.length;
  bool get hasPackage => package != null;

  GradingState copyWith({
    ExamPackage? package,
    List<File>? submissions,
    Map<String, GradingEntry>? entries,
    List<String>? markerOptions,
    String? selectedMarker,
    GradingGuide? gradingGuide,
    int? currentIndex,
    StudentSubmission? currentSubmission,
    bool clearCurrentSubmission = false,
    bool? isLoading,
    bool? isSaving,
    bool? autoSave,
    bool? isDirty,
    String? errorMessage,
    bool clearError = false,
    String? statusMessage,
  }) {
    return GradingState(
      package: package ?? this.package,
      submissions: submissions ?? this.submissions,
      entries: entries ?? this.entries,
      markerOptions: markerOptions ?? this.markerOptions,
      selectedMarker: selectedMarker ?? this.selectedMarker,
      gradingGuide: gradingGuide ?? this.gradingGuide,
      currentIndex: currentIndex ?? this.currentIndex,
      currentSubmission: clearCurrentSubmission
          ? null
          : currentSubmission ?? this.currentSubmission,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      autoSave: autoSave ?? this.autoSave,
      isDirty: isDirty ?? this.isDirty,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

class GradingController extends Notifier<GradingState> {
  final PackageDetector _detector = PackageDetector();
  final SubmissionParser _parser = SubmissionParser();
  final DocxTextReader _docxTextReader = const DocxTextReader();
  final ExcelGradeRepository _repository = ExcelGradeRepository();
  Map<String, GradingEntry> _lastSavedEntries = {};

  @override
  GradingState build() => const GradingState();

  Future<void> loadPackage(String path) async {
    state = state.copyWith(
      isLoading: true,
      clearCurrentSubmission: true,
      clearError: true,
      statusMessage: 'Scanning package...',
    );
    try {
      final examPackage = await _detector.detect(path);
      final aliases = examPackage.studentFiles.map(aliasFromFile).toList();
      final entries = await _repository.open(
        examPackage.markSheetFile,
        aliases,
      );
      final markerOptions = _repository.markerOptions;
      final guide = await _readGradingGuide(examPackage);
      _lastSavedEntries = Map<String, GradingEntry>.from(entries);
      state = state.copyWith(
        package: examPackage,
        submissions: examPackage.studentFiles,
        entries: entries,
        markerOptions: markerOptions,
        selectedMarker: '',
        gradingGuide: guide,
        currentIndex: 0,
        isDirty: false,
        statusMessage: 'Loaded ${examPackage.studentFiles.length} submissions.',
      );
      await _loadCurrentSubmission();
    } catch (error) {
      state = state.copyWith(
        errorMessage: _messageFor(error),
        statusMessage: 'Package load failed.',
      );
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> saveCurrent() async {
    final entry = state.currentEntry;
    if (entry == null) {
      return true;
    }

    for (var i = 0; i < entry.requestScores.length; i++) {
      final score = entry.requestScores[i];
      final maxScore = state.gradingGuide.maxScores[i];
      if (score != null && maxScore != null && score > maxScore) {
        state = state.copyWith(
          errorMessage: 'Cannot save: Question ${i + 1} score exceeds maximum of $maxScore.',
          clearError: true,
        );
        return false;
      }
    }

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      statusMessage: 'Saving...',
    );
    try {
      await _repository.saveEntry(entry);
      _lastSavedEntries[entry.alias] = entry;
      state = state.copyWith(
        isDirty: false,
        statusMessage: 'Saved ${entry.alias}.',
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        errorMessage: _messageFor(error),
        statusMessage: 'Save failed.',
      );
      return false;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<bool> goToIndex(int index) async {
    final visibleSubmissions = state.visibleSubmissions;
    if (index < 0 ||
        index >= visibleSubmissions.length ||
        index == state.currentIndex) {
      return true;
    }
    if (state.autoSave && state.isDirty) {
      final saved = await saveCurrent();
      if (!saved) {
        return false;
      }
    }
    state = state.copyWith(
      currentIndex: index,
      clearCurrentSubmission: true,
      statusMessage: 'Loading submission...',
    );
    await _loadCurrentSubmission();
    return true;
  }

  Future<bool> nextStudent() => goToIndex(state.currentIndex + 1);
  Future<bool> previousStudent() => goToIndex(state.currentIndex - 1);

  Future<bool> selectMarker(String marker) async {
    state = state.copyWith(
      selectedMarker: marker,
      currentIndex: 0,
      clearCurrentSubmission: true,
      statusMessage: marker.isEmpty
          ? 'Showing all markers.'
          : 'Showing aliases assigned to $marker.',
    );
    await _loadCurrentSubmission();
    return true;
  }

  void setAutoSave(bool enabled) => state = state.copyWith(autoSave: enabled);

  void discardCurrentChanges() {
    final entry = state.currentEntry;
    if (entry == null) {
      return;
    }
    final savedEntry =
        _lastSavedEntries[entry.alias] ??
        GradingEntry.empty(
          entry.alias,
          questionCount: entry.requestScores.length,
        );
    final entries = Map<String, GradingEntry>.from(state.entries);
    entries[entry.alias] = savedEntry;
    state = state.copyWith(
      entries: entries,
      isDirty: false,
      statusMessage: 'Changes discarded.',
    );
  }

  void updateScore(int questionIndex, int? score) {
    final entry = state.currentEntry;
    if (entry == null) {
      return;
    }
    final scores = List<int?>.from(entry.requestScores);
    scores[questionIndex] = score;
    _replaceEntry(entry.copyWith(requestScores: scores));
  }

  void updateComment(String comment) {
    final entry = state.currentEntry;
    if (entry == null) {
      return;
    }
    _replaceEntry(entry.copyWith(comment: comment));
  }

  void clearError() => state = state.copyWith(clearError: true);

  Future<void> openPackageFolder() async {
    final directory = state.package?.rootDirectory;
    if (directory == null) {
      return;
    }
    try {
      await Process.start('explorer.exe', [directory.path]);
    } catch (error) {
      state = state.copyWith(
        errorMessage: _messageFor(error),
        statusMessage: 'Could not open package folder.',
      );
    }
  }

  Future<void> _loadCurrentSubmission() async {
    final visibleSubmissions = state.visibleSubmissions;
    if (visibleSubmissions.isEmpty) {
      state = state.copyWith(
        clearCurrentSubmission: true,
        statusMessage: state.selectedMarker.isEmpty
            ? 'No submissions found.'
            : 'No aliases assigned to ${state.selectedMarker}.',
      );
      return;
    }
    try {
      final submission = await _parser.parse(
        visibleSubmissions[state.currentIndex],
      );
      state = state.copyWith(
        currentSubmission: submission,
        clearError: true,
        statusMessage: 'Viewing ${submission.alias}.',
      );
    } catch (error) {
      state = state.copyWith(
        errorMessage: _messageFor(error),
        statusMessage: 'Submission load failed.',
      );
    }
  }

  void _replaceEntry(GradingEntry entry) {
    final entries = Map<String, GradingEntry>.from(state.entries);
    entries[entry.alias] = entry;
    final isDirty = !_sameEntry(entry, _lastSavedEntries[entry.alias]);
    state = state.copyWith(
      entries: entries,
      isDirty: isDirty,
      statusMessage: isDirty ? 'Unsaved changes.' : 'Saved ${entry.alias}.',
    );
  }

  bool _sameEntry(GradingEntry entry, GradingEntry? other) {
    if (other == null ||
        entry.marker != other.marker ||
        entry.comment != other.comment) {
      return false;
    }
    for (var index = 0; index < entry.requestScores.length; index += 1) {
      if (entry.requestScores[index] != other.requestScores[index]) {
        return false;
      }
    }
    return true;
  }

  String _messageFor(Object error) =>
      error is AppException ? error.message : 'Unexpected error: $error';

  Future<GradingGuide> _readGradingGuide(ExamPackage examPackage) {
    return _docxTextReader.read(examPackage.gradingGuideFile);
  }
}
