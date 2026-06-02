import 'dart:io';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_exception.dart';
import '../core/constants.dart';
import '../submission/submission_models.dart';
import '../config/ai_api_key_store.dart';
import 'ai_grading_audit_log.dart';
import 'ai_grading_service.dart';
import 'ai_grading_validator.dart';
import 'criterion_score_store.dart';
import 'grading_models.dart';
import '../document/docx_parser.dart';
import '../document/question_ocr_reader.dart';
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
    this.criterionScores = const {},
    this.aiSuggestions = const {},
    this.markerOptions = const [],
    this.selectedMarker = '',
    this.gradingGuide = const GradingGuide.empty(),
    this.rubricCriteria = const [],
    this.currentIndex = 0,
    this.currentSubmission,
    this.isLoading = false,
    this.isSaving = false,
    this.isAiGrading = false,
    this.openRouterApiKeyConfigured = false,
    this.openRouterApiKeyInvalid = false,
    this.openRouterApiKeyPreview = '',
    this.openRouterModel = AppConstants.defaultAiModel,
    this.packageContext = '',
    this.questionImageText = '',
    this.autoSave = true,
    this.isDirty = false,
    this.errorMessage,
    this.statusMessage = 'Drop an exam package folder to begin.',
  });

  final ExamPackage? package;
  final List<File> submissions;
  final Map<String, GradingEntry> entries;
  final Map<String, Map<String, int?>> criterionScores;
  final Map<String, AiGradeSuggestion> aiSuggestions;
  final List<String> markerOptions;
  final String selectedMarker;
  final GradingGuide gradingGuide;
  final List<AiRubricCriterion> rubricCriteria;
  final int currentIndex;
  final StudentSubmission? currentSubmission;
  final bool isLoading;
  final bool isSaving;
  final bool isAiGrading;
  final bool openRouterApiKeyConfigured;
  final bool openRouterApiKeyInvalid;
  final String openRouterApiKeyPreview;
  final String openRouterModel;
  final String packageContext;
  final String questionImageText;
  final bool autoSave;
  final bool isDirty;
  final String? errorMessage;
  final String statusMessage;

  GradingEntry? get currentEntry =>
      currentSubmission == null ? null : entries[currentSubmission!.alias];

  Map<String, int?> get currentCriterionScores => currentSubmission == null
      ? const {}
      : criterionScores[currentSubmission!.alias] ?? const {};

  AiGradeSuggestion? get currentAiSuggestion => currentSubmission == null
      ? null
      : aiSuggestions[currentSubmission!.alias];

  bool isAiApplyPending(String alias) {
    final entry = entries[alias];
    final suggestion = aiSuggestions[alias];
    if (entry == null || suggestion == null) {
      return false;
    }
    final teacherCriteria = criterionScores[alias] ?? const {};
    final hasTeacherGrade =
        entry.requestScores.any((score) => score != null) ||
        teacherCriteria.values.any((score) => score != null);
    if (hasTeacherGrade) {
      return false;
    }
    return true;
  }

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
  bool get aiReady => openRouterApiKeyConfigured;
  String get aiReadyLabel => openRouterApiKeyInvalid
      ? 'Invalid Key'
      : aiReady
      ? 'AI: OpenRouter'
      : 'OpenRouter Key';

  GradingState copyWith({
    ExamPackage? package,
    List<File>? submissions,
    Map<String, GradingEntry>? entries,
    Map<String, Map<String, int?>>? criterionScores,
    Map<String, AiGradeSuggestion>? aiSuggestions,
    List<String>? markerOptions,
    String? selectedMarker,
    GradingGuide? gradingGuide,
    List<AiRubricCriterion>? rubricCriteria,
    int? currentIndex,
    StudentSubmission? currentSubmission,
    bool clearCurrentSubmission = false,
    bool? isLoading,
    bool? isSaving,
    bool? isAiGrading,
    bool? openRouterApiKeyConfigured,
    bool? openRouterApiKeyInvalid,
    String? openRouterApiKeyPreview,
    String? openRouterModel,
    String? packageContext,
    String? questionImageText,
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
      criterionScores: criterionScores ?? this.criterionScores,
      aiSuggestions: aiSuggestions ?? this.aiSuggestions,
      markerOptions: markerOptions ?? this.markerOptions,
      selectedMarker: selectedMarker ?? this.selectedMarker,
      gradingGuide: gradingGuide ?? this.gradingGuide,
      rubricCriteria: rubricCriteria ?? this.rubricCriteria,
      currentIndex: currentIndex ?? this.currentIndex,
      currentSubmission: clearCurrentSubmission
          ? null
          : currentSubmission ?? this.currentSubmission,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isAiGrading: isAiGrading ?? this.isAiGrading,
      openRouterApiKeyConfigured:
          openRouterApiKeyConfigured ?? this.openRouterApiKeyConfigured,
      openRouterApiKeyInvalid:
          openRouterApiKeyInvalid ?? this.openRouterApiKeyInvalid,
      openRouterApiKeyPreview:
          openRouterApiKeyPreview ?? this.openRouterApiKeyPreview,
      openRouterModel: openRouterModel ?? this.openRouterModel,
      packageContext: packageContext ?? this.packageContext,
      questionImageText: questionImageText ?? this.questionImageText,
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
  final QuestionOcrReader _questionOcrReader = const QuestionOcrReader();
  final ExcelGradeRepository _repository = ExcelGradeRepository();
  final AiRubricExtractor _rubricExtractor = const AiRubricExtractor();
  final OpenRouterGradingService _openRouterGradingService =
      OpenRouterGradingService();
  final AiApiKeyStore _aiApiKeyStore = const AiApiKeyStore();
  final AiGradingValidator _aiValidator = const AiGradingValidator();
  final AiGradingAuditLog _aiAuditLog = const AiGradingAuditLog();
  final CriterionScoreStore _criterionScoreStore = const CriterionScoreStore();
  Map<String, GradingEntry> _lastSavedEntries = {};
  var _isDisposed = false;

  @override
  GradingState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
    });

    final settings = _aiApiKeyStore.read();
    if (settings.openRouterApiKey != null &&
        !isValidOpenRouterApiKey(settings.openRouterApiKey)) {
      return GradingState(
        openRouterModel: settings.openRouterModel,
        openRouterApiKeyInvalid: true,
        errorMessage:
            'Saved OpenRouter API key is invalid. Please replace it with a key that starts with sk-or-v1-.',
        statusMessage: 'AI settings need attention.',
      );
    }

    _applyAiSettings(settings);
    return GradingState(
      openRouterApiKeyConfigured: _openRouterGradingService.hasApiKey,
      openRouterApiKeyInvalid: false,
      openRouterApiKeyPreview: _openRouterGradingService.apiKeyPreview,
      openRouterModel: settings.openRouterModel,
    );
  }

  void closePackage() {
    // Reset ve man hinh chon folder, giu lai AI settings.
    _lastSavedEntries = {};
    state = GradingState(
      openRouterApiKeyConfigured: _openRouterGradingService.hasApiKey,
      openRouterApiKeyInvalid: false,
      openRouterApiKeyPreview: _openRouterGradingService.apiKeyPreview,
      openRouterModel: _openRouterGradingService.model,
      statusMessage: 'Drop an exam package folder to begin.',
    );
  }

  Future<void> loadPackage(String path) async {
    // Flow load package:
    // 1) PackageDetector.detect(path) kiem tra folder dau vao.
    // 2) ExcelGradeRepository.open(...) doc file diem va entry tung alias.
    // 3) DocxTextReader.read(...) doc rubric tu DOCX.
    // 4) _loadCurrentSubmission() doc bai nop dau tien.
    state = state.copyWith(
      isLoading: true,
      clearCurrentSubmission: true,
      clearError: true,
      statusMessage: 'Scanning package...',
    );
    try {
      final examPackage = await _detector.detect(path);
      final aliases = examPackage.studentFiles.map(aliasFromFile).toList();
      // Sau khi co danh sach alias, doc Excel de lay diem/marker/comment hien co.
      final entries = await _repository.open(
        examPackage.markSheetFile,
        aliases,
      );
      final markerOptions = _repository.markerOptions;
      // Doc huong dan cham tu DOCX de SubmissionViewer render o tab Grading Guide.
      final guide = await _readGradingGuide(examPackage);
      final questionImageText = await _questionOcrReader.read(
        examPackage.questionImageFile,
      );
      final rubricCriteria = _rubricExtractor.extract(guide);
      final packageContext = _buildPackageContext(
        rubricCriteria: rubricCriteria,
        questionImageText: questionImageText,
      );
      final criterionScores = await _criterionScoreStore.load(
        packageDirectory: examPackage.rootDirectory,
        aliases: aliases,
        criteria: rubricCriteria,
      );
      final aiSuggestions = await _criterionScoreStore.loadAiSuggestions(
        packageDirectory: examPackage.rootDirectory,
        aliases: aliases,
        criteria: rubricCriteria,
      );
      _lastSavedEntries = Map<String, GradingEntry>.from(entries);
      state = state.copyWith(
        package: examPackage,
        submissions: examPackage.studentFiles,
        entries: entries,
        criterionScores: criterionScores,
        aiSuggestions: aiSuggestions,
        markerOptions: markerOptions,
        selectedMarker: '',
        gradingGuide: guide,
        rubricCriteria: rubricCriteria,
        packageContext: packageContext,
        questionImageText: questionImageText,
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
    // Luu entry hien tai xuong Excel.
    // Flow tiep theo: ExcelGradeRepository.saveEntry -> XlsxCellWriter.patch.
    final entry = state.currentEntry;
    if (entry == null) {
      return true;
    }

    for (var i = 0; i < entry.requestScores.length; i++) {
      final score = entry.requestScores[i];
      final maxScore = state.gradingGuide.maxScores[i];
      if (score != null && maxScore != null && score > maxScore) {
        state = state.copyWith(
          errorMessage:
              'Cannot save: Question ${i + 1} score exceeds maximum of $maxScore.',
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
      final package = state.package;
      if (package != null) {
        await _criterionScoreStore.saveTeacher(
          packageDirectory: package.rootDirectory,
          entry: entry,
          criterionScores: state.currentCriterionScores,
        );
      }
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
    // Doi sang sinh vien khac. Neu autosave dang bat va co thay doi,
    // luu current entry truoc, roi moi parse bai nop moi bang _loadCurrentSubmission.
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

  Future<bool> goToAlias(String alias) async {
    final normalizedAlias = alias.trim();
    if (normalizedAlias.isEmpty) {
      return true;
    }
    final visibleSubmissions = state.visibleSubmissions;
    final targetIndex = visibleSubmissions.indexWhere(
      (file) => _sameAlias(aliasFromFile(file), normalizedAlias),
    );
    if (targetIndex < 0) {
      state = state.copyWith(
        errorMessage:
            'Alias $normalizedAlias was not found in the current list.',
        statusMessage: 'Alias not found.',
      );
      return false;
    }
    return goToIndex(targetIndex);
  }

  bool _sameAlias(String left, String right) {
    if (left == right) {
      return true;
    }
    final leftNumber = int.tryParse(left);
    final rightNumber = int.tryParse(right);
    return leftNumber != null &&
        rightNumber != null &&
        leftNumber == rightNumber;
  }

  Future<bool> selectMarker(String marker) async {
    // Doi bo loc marker. visibleSubmissions trong GradingState se tu filter
    // theo marker, sau do load lai bai dau tien cua danh sach moi.
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
// lưu API key 
  Future<bool> saveAiSettings({
    required String openRouterApiKey,
    required String openRouterModel,
  }) async {
    final previous = _aiApiKeyStore.read();
    final trimmedKey = openRouterApiKey.trim();
    if (trimmedKey.isNotEmpty && !isValidOpenRouterApiKey(trimmedKey)) {
      state = state.copyWith(
        errorMessage:
            'OpenRouter API key must start with sk-or-v1-. Please paste an OpenRouter key.',
        openRouterApiKeyInvalid: true,
        statusMessage: 'AI settings not saved.',
      );
      return false;
    }
    final settings = AiSettings(
      openRouterApiKey: trimmedKey.isEmpty
          ? previous.openRouterApiKey
          : trimmedKey,
      openRouterModel: openRouterModel,
    );
    _applyAiSettings(settings);
    await _aiApiKeyStore.save(settings);
    state = state.copyWith(
      openRouterApiKeyConfigured: _openRouterGradingService.hasApiKey,
      openRouterApiKeyInvalid: false,
      openRouterApiKeyPreview: _openRouterGradingService.apiKeyPreview,
      openRouterModel: settings.openRouterModel,
      statusMessage: 'AI settings saved.',
    );
    return true;
  }

  Future<void> clearOpenRouterApiKey() async {
    _openRouterGradingService.clearApiKey();
    final settings = _aiApiKeyStore.read().copyWith(
      clearOpenRouterApiKey: true,
    );
    await _aiApiKeyStore.save(settings);
    state = state.copyWith(
      openRouterApiKeyConfigured: false,
      openRouterApiKeyInvalid: false,
      openRouterApiKeyPreview: '',
      statusMessage: 'OpenRouter API key cleared.',
    );
  }

  void discardCurrentChanges() {
    // Khoi phuc entry hien tai ve ban da luu gan nhat trong _lastSavedEntries.
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
    // User sua diem mot cau. Cap nhat requestScores roi goi _replaceEntry
    // de update state va tinh isDirty.
    final entry = state.currentEntry;
    if (entry == null) {
      return;
    }
    final scores = List<int?>.from(entry.requestScores);
    scores[questionIndex] = score;
    _replaceEntry(entry.copyWith(requestScores: scores));
  }

  void updateCriterionScore(String criterionId, int? score) {
    final entry = state.currentEntry;
    final submission = state.currentSubmission;
    if (entry == null || submission == null) {
      return;
    }

    final criteria = state.rubricCriteria;
    AiRubricCriterion? criterion;
    for (final item in criteria) {
      if (item.id == criterionId) {
        criterion = item;
        break;
      }
    }
    if (criterion == null) {
      return;
    }
    final selectedCriterion = criterion;

    final aliasScores = Map<String, int?>.from(state.currentCriterionScores);
    final normalizedScore = score?.clamp(0, selectedCriterion.maxScore).toInt();
    aliasScores[criterionId] = normalizedScore;
    final allScores = Map<String, Map<String, int?>>.from(
      state.criterionScores,
    );
    allScores[submission.alias] = aliasScores;

    final questionScores = List<int?>.from(entry.requestScores);
    final questionCriteria = criteria
        .where((item) => item.questionIndex == selectedCriterion.questionIndex)
        .toList();
    questionScores[selectedCriterion.questionIndex] = questionCriteria
        .fold<int>(0, (sum, item) => sum + (aliasScores[item.id] ?? 0));

    state = state.copyWith(criterionScores: allScores);
    _replaceEntry(entry.copyWith(requestScores: questionScores));
  }

  void updateComment(String comment) {
    // User sua comment. Cap nhat entry roi goi _replaceEntry.
    final entry = state.currentEntry;
    if (entry == null) {
      return;
    }
    _replaceEntry(entry.copyWith(comment: comment));
  }

  void applyAiSuggestionToTeacherGrade() {
    final entry = state.currentEntry;
    final submission = state.currentSubmission;
    final suggestion = state.currentAiSuggestion;
    if (entry == null || submission == null || suggestion == null) {
      return;
    }

    final allCriterionScores = Map<String, Map<String, int?>>.from(
      state.criterionScores,
    );
    allCriterionScores[submission.alias] = Map<String, int?>.from(
      suggestion.criterionScores,
    );
    state = state.copyWith(criterionScores: allCriterionScores);

    _replaceEntry(
      entry.copyWith(
        requestScores: List<int?>.from(suggestion.questionScores),
        comment: suggestion.combinedComment,
      ),
    );
  }

  Future<void> applyAiSuggestionsToVisibleBatch() async {
    final package = state.package;
    if (package == null) {
      return;
    }

    final targets = [
      for (final file in state.visibleSubmissions)
        if (state.isAiApplyPending(aliasFromFile(file))) aliasFromFile(file),
    ];

    if (targets.isEmpty) {
      state = state.copyWith(
        statusMessage: 'No AI suggestions to apply in this scope.',
      );
      return;
    }

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      statusMessage: 'Applying AI to ${targets.length} teacher grades...',
    );

    final entries = Map<String, GradingEntry>.from(state.entries);
    final allCriterionScores = Map<String, Map<String, int?>>.from(
      state.criterionScores,
    );
    final errors = <String>[];
    var appliedCount = 0;

    try {
      for (final alias in targets) {
        final entry = entries[alias];
        final suggestion = state.aiSuggestions[alias];
        if (entry == null || suggestion == null) {
          errors.add('$alias: missing entry or AI suggestion.');
          continue;
        }

        final appliedEntry = entry.copyWith(
          requestScores: List<int?>.from(suggestion.questionScores),
          comment: suggestion.combinedComment,
        );
        final criterionScores = Map<String, int?>.from(
          suggestion.criterionScores,
        );

        await _repository.saveEntry(appliedEntry);
        await _criterionScoreStore.saveTeacher(
          packageDirectory: package.rootDirectory,
          entry: appliedEntry,
          criterionScores: criterionScores,
        );

        entries[alias] = appliedEntry;
        allCriterionScores[alias] = criterionScores;
        _lastSavedEntries[alias] = appliedEntry;
        appliedCount += 1;
      }

      final currentAlias = state.currentSubmission?.alias;
      final currentEntry = currentAlias == null ? null : entries[currentAlias];
      final currentDirty = currentEntry == null
          ? state.isDirty
          : !_sameEntry(currentEntry, _lastSavedEntries[currentAlias]);

      state = state.copyWith(
        entries: entries,
        criterionScores: allCriterionScores,
        isDirty: currentDirty,
        errorMessage: errors.isEmpty ? null : errors.take(5).join('\n'),
        clearError: errors.isEmpty,
        statusMessage: errors.isEmpty
            ? 'Applied AI to $appliedCount teacher grades.'
            : 'Applied AI to $appliedCount/${targets.length}; ${errors.length} need review.',
      );
    } catch (error) {
      state = state.copyWith(
        errorMessage: _messageFor(error),
        statusMessage: 'Batch apply failed.',
      );
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<void> suggestAiGrade() async {
    // AI chi de xuat diem. Diem chi duoc apply vao panel sau khi qua validator.
    final package = state.package;
    final submission = state.currentSubmission;
    final entry = state.currentEntry;
    if (package == null || submission == null || entry == null) {
      return;
    }

    AiGradingResult? aiResult;
    AiValidationResult? validation;
    state = state.copyWith(
      isAiGrading: true,
      clearError: true,
      statusMessage: 'AI is grading ${submission.alias}...',
    );

    try {
      final criteria = state.rubricCriteria;
      if (criteria.isEmpty) {
        throw const AiGradingException(
          'Could not detect rubric criteria such as 1.1, 1.2 from the grading guide.',
        );
      }

      final request = AiGradingRequest(
        submission: submission,
        criteria: criteria,
        questionCount: entry.requestScores.length,
        packageContext: state.packageContext,
      );
      _openRouterGradingService.setModel(state.openRouterModel);
      aiResult = await _openRouterGradingService.grade(request);
      if (_isDisposed) {
        return;
      }
      validation = _aiValidator.validate(
        result: aiResult,
        rubric: criteria,
        questionCount: entry.requestScores.length,
        submissionContent: submission.content,
      );

      await _aiAuditLog.saveAi(
        packageDirectory: package.rootDirectory,
        submission: submission,
        model: _activeModelName(),
        rawResult: aiResult,
        validation: validation,
      );
      if (_isDisposed) {
        return;
      }

      if (!validation.accepted) {
        state = state.copyWith(
          errorMessage: validation.errors.join('\n'),
          statusMessage: 'AI grade rejected by validation rules.',
        );
        return;
      }

      _applyAiResult(
        submission: submission,
        result: aiResult,
        validation: validation,
      );
      state = state.copyWith(
        statusMessage: 'AI grade suggested for ${submission.alias}.',
      );
    } catch (error) {
      await _aiAuditLog.saveAi(
        packageDirectory: package.rootDirectory,
        submission: submission,
        model: _activeModelName(),
        rawResult: aiResult,
        validation: validation,
        error: error,
      );
      if (_isDisposed) {
        return;
      }
      state = state.copyWith(
        errorMessage: _messageFor(error),
        statusMessage: 'AI grading failed.',
      );
    } finally {
      if (!_isDisposed) {
        state = state.copyWith(isAiGrading: false);
      }
    }
  }

  Future<void> suggestAiGradesForVisibleBatch() async {
    final package = state.package;
    if (package == null) {
      return;
    }

    final targets = [
      for (final file in state.visibleSubmissions)
        if (!state.aiSuggestions.containsKey(aliasFromFile(file))) file,
    ];
    if (targets.isEmpty) {
      state = state.copyWith(
        statusMessage: state.selectedMarker.isEmpty
            ? 'All submissions already have AI grades.'
            : 'All visible marker submissions already have AI grades.',
      );
      return;
    }

    state = state.copyWith(
      isAiGrading: true,
      clearError: true,
      statusMessage: 'AI batch grading ${targets.length} submissions...',
    );

    final parsedSubmissions = <StudentSubmission>[];
    try {
      final criteria = state.rubricCriteria;
      if (criteria.isEmpty) {
        throw const AiGradingException(
          'Could not detect rubric criteria such as 1.1, 1.2 from the grading guide.',
        );
      }

      for (final file in targets) {
        parsedSubmissions.add(await _parser.parse(file));
        if (_isDisposed) {
          return;
        }
      }

      final firstEntry = state.entries[parsedSubmissions.first.alias];
      if (firstEntry == null) {
        throw const AiGradingException(
          'Could not find a grade entry for the first selected submission.',
        );
      }

      final suggestions = Map<String, AiGradeSuggestion>.from(
        state.aiSuggestions,
      );
      final errors = <String>[];
      var acceptedCount = 0;

      _openRouterGradingService.setModel(state.openRouterModel);
      const chunkSize = AppConstants.aiBatchChunkSize;
      for (
        var start = 0;
        start < parsedSubmissions.length;
        start += chunkSize
      ) {
        final nextEnd = start + chunkSize;
        final end = nextEnd > parsedSubmissions.length
            ? parsedSubmissions.length
            : nextEnd;
        final chunk = parsedSubmissions.sublist(start, end);
        if (_isDisposed) {
          return;
        }
        state = state.copyWith(
          statusMessage:
              'AI batch grading ${start + 1}-$end/${parsedSubmissions.length}...',
        );

        late final AiBatchGradingResult batchResult;
        try {
          batchResult = chunk.length == 1
              ? AiBatchGradingResult(
                  results: {
                    chunk.first.alias: await _openRouterGradingService.grade(
                      AiGradingRequest(
                        submission: chunk.first,
                        criteria: criteria,
                        questionCount: firstEntry.requestScores.length,
                        packageContext: state.packageContext,
                      ),
                    ),
                  },
                )
              : await _openRouterGradingService.gradeBatch(
                  AiBatchGradingRequest(
                    submissions: chunk,
                    criteria: criteria,
                    questionCount: firstEntry.requestScores.length,
                    packageContext: state.packageContext,
                  ),
                );
        } catch (error) {
          for (final submission in chunk) {
            await _aiAuditLog.saveAi(
              packageDirectory: package.rootDirectory,
              submission: submission,
              model: _activeModelName(),
              rawResult: null,
              validation: null,
              error: error,
            );
            if (_isDisposed) {
              return;
            }
            errors.add('${submission.alias}: ${_messageFor(error)}');
          }
          continue;
        }

        for (final submission in chunk) {
          final entry = state.entries[submission.alias];
          final result = batchResult.results[submission.alias];
          final resultError = batchResult.errors[submission.alias];
          AiValidationResult? validation;

          if (entry == null) {
            errors.add('${submission.alias}: grade entry not found.');
            continue;
          }

          if (resultError != null) {
            final error = AiGradingException(resultError);
            await _aiAuditLog.saveAi(
              packageDirectory: package.rootDirectory,
              submission: submission,
              model: _activeModelName(),
              rawResult: null,
              validation: null,
              error: error,
            );
            errors.add('${submission.alias}: $resultError');
            continue;
          }

          if (result == null) {
            final error = AiGradingException(
              'AI batch response did not include alias ${submission.alias}.',
            );
            await _aiAuditLog.saveAi(
              packageDirectory: package.rootDirectory,
              submission: submission,
              model: _activeModelName(),
              rawResult: null,
              validation: null,
              error: error,
            );
            errors.add('${submission.alias}: missing from AI response.');
            continue;
          }

          validation = _aiValidator.validate(
            result: result,
            rubric: criteria,
            questionCount: entry.requestScores.length,
            submissionContent: submission.content,
          );

          await _aiAuditLog.saveAi(
            packageDirectory: package.rootDirectory,
            submission: submission,
            model: _activeModelName(),
            rawResult: result,
            validation: validation,
          );
          if (_isDisposed) {
            return;
          }

          if (!validation.accepted) {
            errors.add('${submission.alias}: ${validation.errors.join('; ')}');
            continue;
          }

          suggestions[submission.alias] = AiGradeSuggestion(
            questionScores: validation.questionScores,
            criterionScores: validation.criterionScores,
            comments: result.comments,
            warnings: validation.warnings,
          );
          acceptedCount += 1;
        }

        if (_isDisposed) {
          return;
        }
        state = state.copyWith(aiSuggestions: suggestions);
      }

      if (_isDisposed) {
        return;
      }
      state = state.copyWith(
        aiSuggestions: suggestions,
        errorMessage: errors.isEmpty ? null : errors.take(5).join('\n'),
        clearError: errors.isEmpty,
        statusMessage: errors.isEmpty
            ? 'AI batch suggested $acceptedCount submissions.'
            : 'AI batch suggested $acceptedCount/${targets.length}; ${errors.length} need review.',
      );
    } catch (error) {
      if (_isDisposed) {
        return;
      }
      state = state.copyWith(
        errorMessage: _messageFor(error),
        statusMessage: 'AI batch grading failed.',
      );
    } finally {
      if (!_isDisposed) {
        state = state.copyWith(isAiGrading: false);
      }
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  Future<void> openPackageFolder() async {
    // Mo folder package bang Windows Explorer.
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
    // Lay file bai nop theo currentIndex trong danh sach da filter,
    // sau do SubmissionParser.parse(file) doc noi dung .txt.
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
    // Thay entry trong map state.entries. So voi _lastSavedEntries de biet
    // co thay doi chua luu hay khong.
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
    // So sanh entry dang sua voi entry da luu gan nhat.
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

  String _messageFor(Object error) => error is AppException
      ? error.message
      : error is AiGradingException
      ? error.message
      : error is TimeoutException
      ? 'AI request timed out. Try a smaller/faster model or run again later.'
      : 'Unexpected error: $error';

  void _applyAiSettings(AiSettings settings) {
    _openRouterGradingService.configure(
      apiKey: settings.openRouterApiKey,
      model: settings.openRouterModel,
    );
  }

  String _activeModelName() => 'openrouter:${_openRouterGradingService.model}';

  void _applyAiResult({
    required StudentSubmission submission,
    required AiGradingResult result,
    required AiValidationResult validation,
  }) {
    final suggestions = Map<String, AiGradeSuggestion>.from(
      state.aiSuggestions,
    );
    suggestions[submission.alias] = AiGradeSuggestion(
      questionScores: validation.questionScores,
      criterionScores: validation.criterionScores,
      comments: result.comments,
      warnings: validation.warnings,
    );
    state = state.copyWith(aiSuggestions: suggestions);
  }

  Future<GradingGuide> _readGradingGuide(ExamPackage examPackage) {
    // Ham boc lai DocxTextReader de controller doc grading guide tu package.
    return _docxTextReader.read(examPackage.gradingGuideFile);
  }

  String _buildPackageContext({
    required List<AiRubricCriterion> rubricCriteria,
    required String questionImageText,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('--- EXAM QUESTION TEXT ---');
    buffer.writeln(questionImageText);
    buffer.writeln(
      '\n--- RUBRIC CRITERIA (authoritative; includes common mistakes) ---',
    );
    for (final criterion in rubricCriteria) {
      buffer.writeln(criterion.toCompactPromptLine());
    }

    return buffer.toString();
  }
}
