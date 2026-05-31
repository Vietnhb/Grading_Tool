import 'dart:io';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/app_exception.dart';
import '../submission/submission_models.dart';
import 'ai_api_key_store.dart';
import 'ai_grading_audit_log.dart';
import 'ai_grading_service.dart';
import 'ai_grading_validator.dart';
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
    this.criterionScores = const {},
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
    this.openRouterApiKeyPreview = '',
    this.openRouterModel = 'openai/gpt-oss-120b:free',
    this.packageContext = '',
    this.autoSave = true,
    this.isDirty = false,
    this.errorMessage,
    this.statusMessage = 'Drop an exam package folder to begin.',
  });

  final ExamPackage? package;
  final List<File> submissions;
  final Map<String, GradingEntry> entries;
  final Map<String, Map<String, int?>> criterionScores;
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
  final String openRouterApiKeyPreview;
  final String openRouterModel;
  final String packageContext;
  final bool autoSave;
  final bool isDirty;
  final String? errorMessage;
  final String statusMessage;

  GradingEntry? get currentEntry =>
      currentSubmission == null ? null : entries[currentSubmission!.alias];

  Map<String, int?> get currentCriterionScores => currentSubmission == null
      ? const {}
      : criterionScores[currentSubmission!.alias] ?? const {};

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
  String get aiReadyLabel => aiReady ? 'AI: OpenRouter' : 'OpenRouter Key';

  GradingState copyWith({
    ExamPackage? package,
    List<File>? submissions,
    Map<String, GradingEntry>? entries,
    Map<String, Map<String, int?>>? criterionScores,
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
    String? openRouterApiKeyPreview,
    String? openRouterModel,
    String? packageContext,
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
      openRouterApiKeyPreview:
          openRouterApiKeyPreview ?? this.openRouterApiKeyPreview,
      openRouterModel: openRouterModel ?? this.openRouterModel,
      packageContext: packageContext ?? this.packageContext,
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
  final AiRubricExtractor _rubricExtractor = const AiRubricExtractor();
  final OpenRouterGradingService _openRouterGradingService =
      OpenRouterGradingService();
  final AiApiKeyStore _aiApiKeyStore = const AiApiKeyStore();
  final AiGradingValidator _aiValidator = const AiGradingValidator();
  final AiGradingAuditLog _aiAuditLog = const AiGradingAuditLog();
  Map<String, GradingEntry> _lastSavedEntries = {};

  @override
  GradingState build() {
    final settings = _aiApiKeyStore.read();
    _applyAiSettings(settings);
    return GradingState(
      openRouterApiKeyConfigured: _openRouterGradingService.hasApiKey,
      openRouterApiKeyPreview: _openRouterGradingService.apiKeyPreview,
      openRouterModel: settings.openRouterModel,
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
      final rubricCriteria = _rubricExtractor.extract(guide);
      final packageContext = _buildPackageContext(
        examPackage: examPackage,
        rubricCriteria: rubricCriteria,
        guide: guide,
      );
      _logRubricCriteria(rubricCriteria);
      _lastSavedEntries = Map<String, GradingEntry>.from(entries);
      state = state.copyWith(
        package: examPackage,
        submissions: examPackage.studentFiles,
        entries: entries,
        markerOptions: markerOptions,
        selectedMarker: '',
        gradingGuide: guide,
        rubricCriteria: rubricCriteria,
        packageContext: packageContext,
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

  Future<void> saveAiSettings({
    required String openRouterApiKey,
    required String openRouterModel,
  }) async {
    final previous = _aiApiKeyStore.read();
    final settings = AiSettings(
      openRouterApiKey: openRouterApiKey.trim().isEmpty
          ? previous.openRouterApiKey
          : openRouterApiKey.trim(),
      openRouterModel: openRouterModel,
    );
    _applyAiSettings(settings);
    await _aiApiKeyStore.save(settings);
    state = state.copyWith(
      openRouterApiKeyConfigured: _openRouterGradingService.hasApiKey,
      openRouterApiKeyPreview: _openRouterGradingService.apiKeyPreview,
      openRouterModel: settings.openRouterModel,
      statusMessage: 'AI settings saved.',
    );
  }

  Future<void> clearOpenRouterApiKey() async {
    _openRouterGradingService.clearApiKey();
    final settings = _aiApiKeyStore.read().copyWith(
      clearOpenRouterApiKey: true,
    );
    await _aiApiKeyStore.save(settings);
    state = state.copyWith(
      openRouterApiKeyConfigured: false,
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
      validation = _aiValidator.validate(
        result: aiResult,
        rubric: criteria,
        questionCount: entry.requestScores.length,
      );

      await _aiAuditLog.append(
        packageDirectory: package.rootDirectory,
        submission: submission,
        model: _activeModelName(),
        rawResult: aiResult,
        validation: validation,
      );

      if (!validation.accepted) {
        state = state.copyWith(
          errorMessage: validation.errors.join('\n'),
          statusMessage: 'AI grade rejected by validation rules.',
        );
        return;
      }

      _applyAiResult(
        entry: entry,
        submission: submission,
        result: aiResult,
        validation: validation,
      );
      state = state.copyWith(
        statusMessage: 'AI grade suggested for ${submission.alias}.',
      );
    } catch (error) {
      await _aiAuditLog.append(
        packageDirectory: package.rootDirectory,
        submission: submission,
        model: _activeModelName(),
        rawResult: aiResult,
        validation: validation,
        error: error,
      );
      state = state.copyWith(
        errorMessage: _messageFor(error),
        statusMessage: 'AI grading failed.',
      );
    } finally {
      state = state.copyWith(isAiGrading: false);
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
    required GradingEntry entry,
    required StudentSubmission submission,
    required AiGradingResult result,
    required AiValidationResult validation,
  }) {
    final allCriterionScores = Map<String, Map<String, int?>>.from(
      state.criterionScores,
    );
    final aliasScores = Map<String, int?>.from(state.currentCriterionScores);
    for (final item in validation.criterionScores.entries) {
      aliasScores[item.key] = item.value;
    }
    allCriterionScores[submission.alias] = aliasScores;
    state = state.copyWith(criterionScores: allCriterionScores);

    final comment = _commentWithWarnings(
      _commentsForResult(result),
      validation.warnings,
    );
    _replaceEntry(
      entry.copyWith(
        requestScores: validation.questionScores,
        comment: comment,
      ),
    );
  }

  String _commentWithWarnings(String comment, List<String> warnings) {
    if (warnings.isEmpty) {
      return comment;
    }
    return [
      comment,
      '',
      'AI audit warnings:',
      for (final warning in warnings) '- $warning',
    ].join('\n');
  }

  String _commentsForResult(AiGradingResult result) {
    final entries = result.comments.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((entry) => '${entry.key}: ${entry.value}').join('\n');
  }

  void _logRubricCriteria(List<AiRubricCriterion> criteria) {
    for (final criterion in criteria) {
      // ignore: avoid_print
      print(
        [
          'Rubric ${criterion.id}',
          'title=${criterion.title}',
          'maxScore=${criterion.maxScore}',
          'fullCreditDescription=${criterion.fullCreditDescription}',
          'partialCreditDescription=${criterion.partialCreditDescription}',
          'poorCreditDescription=${criterion.poorCreditDescription}',
        ].join(' | '),
      );
    }
  }

  Future<GradingGuide> _readGradingGuide(ExamPackage examPackage) {
    // Ham boc lai DocxTextReader de controller doc grading guide tu package.
    return _docxTextReader.read(examPackage.gradingGuideFile);
  }

  String _buildPackageContext({
    required ExamPackage examPackage,
    required List<AiRubricCriterion> rubricCriteria,
    required GradingGuide guide,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(
      'questionImage=${p.basename(examPackage.questionImageFile.path)}',
    );
    buffer.writeln(
      'gradingGuideFile=${p.basename(examPackage.gradingGuideFile.path)}',
    );
    buffer.writeln('rubricCount=${rubricCriteria.length}');
    buffer.writeln('\n--- RUBRIC (compact lines) ---');
    for (final criterion in rubricCriteria) {
      buffer.writeln(criterion.toCompactPromptLine());
    }
    buffer.writeln('\n--- FULL GRADING GUIDE (do not summarize) ---');
    // Render full guide text so AI sees original guide content verbatim.
    void appendBlock(DocumentBlock block) {
      switch (block) {
        case SectionBlock(:final heading, :final children):
          buffer.writeln(heading.text);
          for (final child in children) appendBlock(child);
        case ParagraphBlock(:final text):
          buffer.writeln(text);
        case BulletListBlock(:final items):
          for (final item in items) buffer.writeln('- ${item.text}');
        case RubricTableBlock(:final rows):
          for (final row in rows) buffer.writeln(row.cells.join(' | '));
      }
    }

    for (final block in guide.blocks) {
      appendBlock(block);
    }

    return buffer.toString();
  }
}
