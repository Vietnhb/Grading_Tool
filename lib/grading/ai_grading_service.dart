import 'dart:convert';
import 'dart:io';

import '../submission/submission_models.dart';
import '../core/constants.dart';
import '../config/ai_api_key_store.dart';
import 'grading_models.dart';

const _aiRequestTimeout = AppConstants.aiRequestTimeout;

class AiRubricCriterion {
  const AiRubricCriterion({
    required this.id,
    required this.title,
    required this.maxScore,
    required this.questionIndex,
    this.fullCreditDescription = '',
    this.partialCreditDescription = '',
    this.poorCreditDescription = '',
    this.fullCreditLabel = 'Full credit',
    this.partialCreditLabel = 'Partial credit',
    this.poorCreditLabel = 'Poor credit',
    this.commonMistakes = const [],
  });

  final String id;
  final String title;
  final int maxScore;
  final int questionIndex;
  final String fullCreditDescription;
  final String partialCreditDescription;
  final String poorCreditDescription;
  final String fullCreditLabel;
  final String partialCreditLabel;
  final String poorCreditLabel;
  final List<String> commonMistakes;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'maxScore': maxScore,
    'questionIndex': questionIndex,
    'fullCreditDescription': fullCreditDescription,
    'partialCreditDescription': partialCreditDescription,
    'poorCreditDescription': poorCreditDescription,
    'fullCreditLabel': fullCreditLabel,
    'partialCreditLabel': partialCreditLabel,
    'poorCreditLabel': poorCreditLabel,
    'commonMistakes': commonMistakes,
  };

  String toCompactPromptLine() {
    final buffer = StringBuffer()
      ..write(id)
      ..write(' | ')
      ..write(title)
      ..write(' | max ')
      ..write(maxScore);
    if (fullCreditDescription.isNotEmpty) {
      buffer.write(' | $fullCreditLabel: $fullCreditDescription');
    }
    if (partialCreditDescription.isNotEmpty) {
      buffer.write(' | $partialCreditLabel: $partialCreditDescription');
    }
    if (poorCreditDescription.isNotEmpty) {
      buffer.write(' | $poorCreditLabel: $poorCreditDescription');
    }
    if (commonMistakes.isNotEmpty) {
      buffer.write(' | mistakes: ${commonMistakes.join('; ')}');
    }
    return buffer.toString();
  }
}

class AiGradingRequest {
  const AiGradingRequest({
    required this.submission,
    required this.criteria,
    required this.questionCount,
    required this.packageContext,
  });

  final StudentSubmission submission;
  final List<AiRubricCriterion> criteria;
  final int questionCount;
  final String packageContext;
}

class AiBatchGradingRequest {
  const AiBatchGradingRequest({
    required this.submissions,
    required this.criteria,
    required this.questionCount,
    required this.packageContext,
  });

  final List<StudentSubmission> submissions;
  final List<AiRubricCriterion> criteria;
  final int questionCount;
  final String packageContext;
}

class AiGradingResult {
  const AiGradingResult({required this.scores, required this.comments});

  factory AiGradingResult.fromJson(Map<String, Object?> json) {
    final rawScores = json['scores'];
    final rawComments = json['comments'];
    if (rawScores is! Map) {
      throw const AiGradingException('AI scores must be a JSON object.');
    }
    if (rawComments is! Map) {
      throw const AiGradingException('AI comments must be a JSON object.');
    }
    final scores = <String, int>{};
    for (final entry in rawScores.entries) {
      if (entry.key is! String || entry.value is! num) {
        throw AiGradingException('Score for ${entry.key} is not a number.');
      }
      scores[entry.key as String] = (entry.value as num).round();
    }
    final comments = <String, String>{};
    for (final entry in rawComments.entries) {
      if (entry.key is String) {
        comments[entry.key as String] = entry.value?.toString() ?? '';
      }
    }
    return AiGradingResult(scores: scores, comments: comments);
  }

  final Map<String, int> scores;
  final Map<String, String> comments;

  Map<String, Object?> toJson() => {'scores': scores, 'comments': comments};
}

class AiBatchGradingResult {
  const AiBatchGradingResult({required this.results, this.errors = const {}});

  factory AiBatchGradingResult.fromJson(Map<String, Object?> json) {
    final rawResults = json['results'];
    if (rawResults is! Map) {
      throw const AiGradingException('AI batch results must be a JSON object.');
    }
    final results = <String, AiGradingResult>{};
    final errors = <String, String>{};
    for (final entry in rawResults.entries) {
      final alias = entry.key.toString();
      final value = entry.value;
      if (value is! Map) {
        errors[alias] = 'AI result must be a JSON object.';
        continue;
      }
      try {
        results[alias] = AiGradingResult.fromJson(
          Map<String, Object?>.from(value),
        );
      } on AiGradingException catch (error) {
        errors[alias] = error.message;
      } on FormatException catch (error) {
        errors[alias] = error.message;
      }
    }
    return AiBatchGradingResult(results: results, errors: errors);
  }

  final Map<String, AiGradingResult> results;
  final Map<String, String> errors;
}

class AiRubricExtractor {
  const AiRubricExtractor();

  List<AiRubricCriterion> extract(GradingGuide guide) {
    final texts = <String>[];
    for (final block in guide.blocks) {
      _flatten(block, texts);
    }

    final criteria = <AiRubricCriterion>[];
    for (var index = 0; index < texts.length - 1; index += 1) {
      final criterionMatch = RegExp(
        r'^(\d+\.\d+)\s+(.+)$',
      ).firstMatch(texts[index]);
      if (criterionMatch == null) {
        continue;
      }

      final scoreMatch = RegExp(r'^(\d+)\s*').firstMatch(texts[index + 1]);
      if (scoreMatch == null) {
        continue;
      }

      final id = criterionMatch.group(1)!;
      if (criteria.any((criterion) => criterion.id == id)) {
        continue;
      }
      criteria.add(
        AiRubricCriterion(
          id: id,
          title: criterionMatch.group(2)!.trim(),
          maxScore: int.parse(scoreMatch.group(1)!),
          questionIndex: criteria
              .map((item) => item.id.split('.').first)
              .toSet()
              .length,
        ),
      );
    }
    return _withTableDescriptions(_normalizeQuestionIndexes(criteria), guide);
  }

  List<AiRubricCriterion> _withTableDescriptions(
    List<AiRubricCriterion> criteria,
    GradingGuide guide,
  ) {
    final descriptions = _rubricRowsById(guide);
    return [
      for (final criterion in criteria)
        _mergeDescription(criterion, descriptions[criterion.id]),
    ];
  }

  AiRubricCriterion _mergeDescription(
    AiRubricCriterion criterion,
    _RubricDescription? description,
  ) {
    if (description == null) {
      return criterion;
    }
    return AiRubricCriterion(
      id: criterion.id,
      title: description.title.isEmpty ? criterion.title : description.title,
      maxScore: description.maxScore ?? criterion.maxScore,
      questionIndex: criterion.questionIndex,
      fullCreditDescription: description.fullCreditDescription,
      partialCreditDescription: description.partialCreditDescription,
      poorCreditDescription: description.poorCreditDescription,
      fullCreditLabel: description.fullCreditLabel,
      partialCreditLabel: description.partialCreditLabel,
      poorCreditLabel: description.poorCreditLabel,
      commonMistakes: description.commonMistakes,
    );
  }

  Map<String, _RubricDescription> _rubricRowsById(GradingGuide guide) {
    final rowsById = <String, _RubricDescription>{};
    _collectRubricRows(guide.blocks, rowsById);
    return rowsById;
  }

  void _collectRubricRows(
    List<DocumentBlock> blocks,
    Map<String, _RubricDescription> rowsById,
  ) {
    var currentCriterionIds = <String>[];
    var currentMistakes = <String>[];
    var collectingMistakes = false;

    void applyCurrentMistakes() {
      if (currentCriterionIds.isEmpty || currentMistakes.isEmpty) {
        return;
      }
      final uniqueMistakes = currentMistakes.toSet().toList();
      for (final id in currentCriterionIds) {
        final description = rowsById[id];
        if (description != null) {
          rowsById[id] = description.copyWith(commonMistakes: uniqueMistakes);
        }
      }
    }

    for (final block in blocks) {
      switch (block) {
        case SectionBlock(:final children):
          _collectRubricRows(children, rowsById);
        case RubricTableBlock(:final rows):
          applyCurrentMistakes();
          currentCriterionIds = [];
          currentMistakes = [];
          var labels = const _RubricLevelLabels();
          for (final row in rows) {
            final headerLabels = _labelsFromHeaderRow(row);
            if (headerLabels != null) {
              labels = headerLabels;
              continue;
            }
            final description = _descriptionFromRow(row, labels);
            if (description != null) {
              rowsById[description.id] = description;
              currentCriterionIds.add(description.id);
            }
          }
          collectingMistakes = false;
        case ParagraphBlock(:final text):
          final normalized = text.toLowerCase();
          if (normalized.contains('lỗi thường gặp') ||
              normalized.contains('common mistake')) {
            collectingMistakes = true;
          } else if (collectingMistakes && text.trim().isNotEmpty) {
            currentMistakes.add(text.trim());
          }
        case BulletListBlock(:final items):
          if (collectingMistakes) {
            currentMistakes.addAll(items.map((item) => item.text.trim()));
          }
      }
    }

    applyCurrentMistakes();
  }

  _RubricLevelLabels? _labelsFromHeaderRow(RubricTableRowBlock row) {
    if (row.cells.length < 5) {
      return null;
    }
    final firstCell = row.cells.first.toLowerCase();
    final joinedLevelHeaders = row.cells.skip(2).take(3).join(' ');
    final looksLikeCriterionRow = RegExp(r'^\d+\.\d+').hasMatch(firstCell);
    final isHeader =
        row.isHeader ||
        (!looksLikeCriterionRow && joinedLevelHeaders.contains('%')) ||
        firstCell.contains('criterion');
    if (!isHeader) {
      return null;
    }
    return _RubricLevelLabels(
      fullCreditLabel: row.cells[2].trim(),
      partialCreditLabel: row.cells[3].trim(),
      poorCreditLabel: row.cells[4].trim(),
    );
  }

  _RubricDescription? _descriptionFromRow(
    RubricTableRowBlock row,
    _RubricLevelLabels labels,
  ) {
    if (row.cells.length < 5 || row.isHeader) {
      return null;
    }
    final idMatch = RegExp(r'^(\d+\.\d+)\s*(.*)$').firstMatch(row.cells[0]);
    if (idMatch == null) {
      return null;
    }
    return _RubricDescription(
      id: idMatch.group(1)!,
      title: idMatch.group(2)!.trim(),
      maxScore: int.tryParse(
        RegExp(r'\d+').firstMatch(row.cells[1])?.group(0) ?? '',
      ),
      fullCreditDescription: row.cells[2].trim(),
      partialCreditDescription: row.cells[3].trim(),
      poorCreditDescription: row.cells[4].trim(),
      fullCreditLabel: labels.fullCreditLabel,
      partialCreditLabel: labels.partialCreditLabel,
      poorCreditLabel: labels.poorCreditLabel,
    );
  }

  List<AiRubricCriterion> _normalizeQuestionIndexes(
    List<AiRubricCriterion> criteria,
  ) {
    final questionNumbers = <String>[];
    for (final criterion in criteria) {
      final questionNumber = criterion.id.split('.').first;
      if (!questionNumbers.contains(questionNumber)) {
        questionNumbers.add(questionNumber);
      }
    }
    return [
      for (final criterion in criteria)
        AiRubricCriterion(
          id: criterion.id,
          title: criterion.title,
          maxScore: criterion.maxScore,
          questionIndex: questionNumbers.indexOf(criterion.id.split('.').first),
          fullCreditDescription: criterion.fullCreditDescription,
          partialCreditDescription: criterion.partialCreditDescription,
          poorCreditDescription: criterion.poorCreditDescription,
          fullCreditLabel: criterion.fullCreditLabel,
          partialCreditLabel: criterion.partialCreditLabel,
          poorCreditLabel: criterion.poorCreditLabel,
          commonMistakes: criterion.commonMistakes,
        ),
    ];
  }

  void _flatten(DocumentBlock block, List<String> texts) {
    switch (block) {
      case SectionBlock(:final heading, :final children):
        texts.add(heading.text.trim());
        for (final child in children) {
          _flatten(child, texts);
        }
      case ParagraphBlock(:final text):
        texts.add(text.trim());
      case BulletListBlock(:final items):
        texts.addAll(items.map((item) => item.text.trim()));
      case RubricTableBlock(:final rows):
        for (final row in rows) {
          texts.addAll(row.cells.map((cell) => cell.trim()));
        }
    }
  }
}

class _RubricLevelLabels {
  const _RubricLevelLabels({
    this.fullCreditLabel = 'Full credit',
    this.partialCreditLabel = 'Partial credit',
    this.poorCreditLabel = 'Poor credit',
  });

  final String fullCreditLabel;
  final String partialCreditLabel;
  final String poorCreditLabel;
}

class _RubricDescription {
  const _RubricDescription({
    required this.id,
    required this.title,
    required this.maxScore,
    required this.fullCreditDescription,
    required this.partialCreditDescription,
    required this.poorCreditDescription,
    required this.fullCreditLabel,
    required this.partialCreditLabel,
    required this.poorCreditLabel,
    this.commonMistakes = const [],
  });

  final String id;
  final String title;
  final int? maxScore;
  final String fullCreditDescription;
  final String partialCreditDescription;
  final String poorCreditDescription;
  final String fullCreditLabel;
  final String partialCreditLabel;
  final String poorCreditLabel;
  final List<String> commonMistakes;

  _RubricDescription copyWith({List<String>? commonMistakes}) {
    return _RubricDescription(
      id: id,
      title: title,
      maxScore: maxScore,
      fullCreditDescription: fullCreditDescription,
      partialCreditDescription: partialCreditDescription,
      poorCreditDescription: poorCreditDescription,
      fullCreditLabel: fullCreditLabel,
      partialCreditLabel: partialCreditLabel,
      poorCreditLabel: poorCreditLabel,
      commonMistakes: commonMistakes ?? this.commonMistakes,
    );
  }
}

class OpenRouterGradingService {
  OpenRouterGradingService({
    HttpClient? httpClient,
    String? apiKey,
    this.model = AppConstants.defaultAiModel,
  }) : _httpClient = httpClient ?? HttpClient(),
       _apiKey = apiKey ?? Platform.environment['OPENROUTER_API_KEY'];

  final HttpClient _httpClient;
  String? _apiKey;
  String model;

  bool get hasApiKey => _apiKey != null && _apiKey!.trim().isNotEmpty;

  String get apiKeyPreview {
    final apiKey = _apiKey;
    if (apiKey == null || apiKey.length < 8) {
      return '';
    }
    return '${apiKey.substring(0, 7)}...${apiKey.substring(apiKey.length - 4)}';
  }

  void configure({String? apiKey, required String model}) {
    final trimmed = apiKey?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      _apiKey = trimmed;
    }
    this.model = model.trim().isEmpty
        ? AppConstants.defaultAiModel
        : model.trim();
  }

  void clearApiKey() => _apiKey = null;

  void setModel(String model) {
    final trimmed = model.trim();
    this.model = trimmed.isEmpty ? AppConstants.defaultAiModel : trimmed;
  }

  Future<AiGradingResult> grade(AiGradingRequest request) async {
    final apiKey = _apiKey?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      throw const AiGradingException(
        'OPENROUTER_API_KEY is not set. Add it in AI Settings before using OpenRouter.',
      );
    }
    if (!isValidOpenRouterApiKey(apiKey)) {
      throw const AiGradingException(
        'OpenRouter API key must start with sk-or-v1-. Update it in AI Settings.',
      );
    }

    try {
      return await _withTransientRetries(
        () => _gradeOnce(request, apiKey: apiKey),
      );
    } on FormatException catch (error) {
      throw AiGradingException(
        'AI did not return valid JSON. Details: ${error.message}',
      );
    }
  }

  Future<AiBatchGradingResult> gradeBatch(AiBatchGradingRequest request) async {
    final apiKey = _apiKey?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      throw const AiGradingException(
        'OPENROUTER_API_KEY is not set. Add it in AI Settings before using OpenRouter.',
      );
    }
    if (!isValidOpenRouterApiKey(apiKey)) {
      throw const AiGradingException(
        'OpenRouter API key must start with sk-or-v1-. Update it in AI Settings.',
      );
    }
    try {
      return await _withTransientRetries(
        () => _gradeBatchOnce(request, apiKey: apiKey),
      );
    } on FormatException catch (error) {
      throw AiGradingException(
        'AI did not return valid JSON. Details: ${error.message}',
      );
    }
  }

  Future<AiGradingResult> _gradeOnce(
    AiGradingRequest request, {
    required String apiKey,
  }) async {
    final httpRequest = await _httpClient.postUrl(
      Uri.parse(AppConstants.openRouterChatCompletionsUrl),
    );
    httpRequest.headers
      ..contentType = ContentType.json
      ..set(HttpHeaders.authorizationHeader, 'Bearer $apiKey')
      ..set('HTTP-Referer', AppConstants.openRouterReferer)
      ..set('X-Title', AppConstants.openRouterTitle);
    final payload = _payloadFor(request);
    final payloadJson = jsonEncode(payload);
    httpRequest.write(payloadJson);

    final response = await httpRequest.close().timeout(_aiRequestTimeout);
    final body = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiGradingException('OpenRouter request failed: $body');
    }

    final decoded = jsonDecode(body) as Map<String, Object?>;
    final error = decoded['error'];
    if (error is Map) {
      final message = error['message']?.toString() ?? error.toString();
      throw AiGradingException('OpenRouter error: $message');
    }

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      throw const AiGradingException(
        'OpenRouter response did not contain choices.',
      );
    }
    final firstChoice = choices.first as Map;
    final message = firstChoice['message'];
    String? content;
    if (message is Map) {
      content = _messageText(message['content']);
    }
    if (content == null || content.trim().isEmpty) {
      if (firstChoice['text'] is String) {
        content = firstChoice['text'] as String;
      } else if (message is Map && message['reasoning'] is String) {
        content = message['reasoning'] as String;
      } else if (message is Map && message['reasoning_content'] is String) {
        content = message['reasoning_content'] as String;
      } else if (message is Map && message['refusal'] != null) {
        throw AiGradingException(
          'OpenRouter refused response: ${message['refusal']}',
        );
      } else if (message is Map && message['tool_calls'] is List) {
        throw const AiGradingException(
          'OpenRouter returned tool calls without content. Choose a model that returns content.',
        );
      }
    }
    if (content == null || content.trim().isEmpty) {
      throw AiGradingException(
        'OpenRouter response did not contain content. '
        'finish_reason=${firstChoice['finish_reason']}',
      );
    }

    final decodedJson = jsonDecode(normalizeAiJsonResponse(content));
    if (decodedJson is! Map<String, dynamic>) {
      throw const AiGradingException(
        'AI output is not a JSON object. No score was applied.',
      );
    }
    return AiGradingResult.fromJson(decodedJson);
  }

  Future<AiBatchGradingResult> _gradeBatchOnce(
    AiBatchGradingRequest request, {
    required String apiKey,
  }) async {
    final httpRequest = await _httpClient.postUrl(
      Uri.parse(AppConstants.openRouterChatCompletionsUrl),
    );
    httpRequest.headers
      ..contentType = ContentType.json
      ..set(HttpHeaders.authorizationHeader, 'Bearer $apiKey')
      ..set('HTTP-Referer', AppConstants.openRouterReferer)
      ..set('X-Title', AppConstants.openRouterTitle);
    httpRequest.write(jsonEncode(_batchPayloadFor(request)));

    final response = await httpRequest.close().timeout(_aiRequestTimeout);
    final body = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiGradingException('OpenRouter request failed: $body');
    }

    final decoded = jsonDecode(body) as Map<String, Object?>;
    final error = decoded['error'];
    if (error is Map) {
      final message = error['message']?.toString() ?? error.toString();
      throw AiGradingException('OpenRouter error: $message');
    }

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      throw const AiGradingException(
        'OpenRouter response did not contain choices.',
      );
    }
    final firstChoice = choices.first as Map;
    final message = firstChoice['message'];
    final content = message is Map ? _messageText(message['content']) : null;
    if (content == null || content.trim().isEmpty) {
      throw AiGradingException(
        'OpenRouter response did not contain content. '
        'finish_reason=${firstChoice['finish_reason']}',
      );
    }

    final decodedJson = jsonDecode(normalizeAiJsonResponse(content));
    if (decodedJson is! Map<String, dynamic>) {
      throw const AiGradingException(
        'AI batch output is not a JSON object. No score was applied.',
      );
    }
    return AiBatchGradingResult.fromJson(decodedJson);
  }

  Future<T> _withTransientRetries<T>(Future<T> Function() request) async {
    AiGradingException? lastError;
    for (
      var attempt = 0;
      attempt <= AppConstants.aiTransientRetryDelays.length;
      attempt += 1
    ) {
      try {
        return await request();
      } on AiGradingException catch (error) {
        if (!_isTransientOpenRouterError(error.message) ||
            attempt == AppConstants.aiTransientRetryDelays.length) {
          rethrow;
        }
        lastError = error;
        await Future<void>.delayed(
          AppConstants.aiTransientRetryDelays[attempt],
        );
      }
    }

    throw lastError ?? const AiGradingException('OpenRouter request failed.');
  }

  bool _isTransientOpenRouterError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('429') ||
        normalized.contains('503') ||
        normalized.contains('rate-limit') ||
        normalized.contains('rate limit') ||
        normalized.contains('capacity_error') ||
        normalized.contains('no backends available') ||
        normalized.contains('temporarily rate-limited');
  }

  Map<String, Object?> _payloadFor(AiGradingRequest request) {
    final maxScores = <String, int>{
      for (final c in request.criteria) c.id: c.maxScore,
    };
    final rangeList = request.criteria
        .map((c) => '${c.id}:0-${c.maxScore}')
        .join(', ');
    final messages = <Map<String, Object?>>[
      {
        'role': 'system',
        'content':
            'You are a strict grading API. Return exactly one valid JSON object with only these keys: scores, comments. '
            'scores must be an object mapping every criterion id to an integer. comments must be an object mapping every criterion id to a Vietnamese string. '
            'Never return comments as a plain string, list, null, or nested object. '
            'Do not use Markdown or code fences. '
            'ALLOWED SCORE RANGES (score MUST be within these ranges): $rangeList. '
            'Use maxScores/criterionMaxScores as hard upper bounds; never return a score outside 0..maxScore for that criterion. '
            'Grade every rubric criterion listed in criterionIds exactly once. Comments must be short Vietnamese reasons. '
            'Before returning, verify internally that scores contains every criterionId and every score is inside its allowed range. '
            'Use packageContext as authoritative: exam question text, rubric criteria, rubric table level labels, and common mistakes. '
            'Interpret each rubric level by its original table label, including percentages such as 100%, 50-70%, or <50% when present. '
            'Student answers may be organized with labels like Request 1, Request 2, Question 1, or Question 2; treat those sections as the student answer, not as automatic copied-question text. '
            'If the submission copies parts of the exam question, still grade any additional usable answer content and award partial credit when rubric evidence is present. '
            'Student English may be broken; grade the intended project-management content, not grammar or spelling. '
            'Do not mark a criterion zero when the submission has a recognizable attempt related to that criterion; award partial credit instead. '
            'A total score of zero is valid only when the whole submission is blank, unrelated, or unusable. '
            'Each comment must mention the concrete evidence found or the concrete missing requirement. '
            'Grade by semantic content, accept imperfect wording, award partial credit for relevant incomplete answers, and give zero only when missing/unrelated/contradictory.',
      },
      {
        'role': 'user',
        'content': jsonEncode({
          'outputSchema':
              '{"scores":{"1.1":2,"1.2":3},"comments":{"1.1":"Vietnamese reason.","1.2":"Vietnamese reason."}}',
          'criterionIds': [
            for (final criterion in request.criteria) criterion.id,
          ],
          'maxScores': maxScores,
          'criterionMaxScores': maxScores,
          'packageContext': request.packageContext,
          'submission': {
            'alias': request.submission.alias,
            'content': request.submission.content,
          },
        }),
      },
    ];

    return {
      'model': model,
      'temperature': AppConstants.aiTemperature,
      'max_completion_tokens': AppConstants.aiMaxTokens,
      'messages': messages,
    };
  }

  Map<String, Object?> _batchPayloadFor(AiBatchGradingRequest request) {
    final maxScores = <String, int>{
      for (final c in request.criteria) c.id: c.maxScore,
    };
    final rangeList = request.criteria
        .map((c) => '${c.id}:0-${c.maxScore}')
        .join(', ');
    final messages = <Map<String, Object?>>[
      {
        'role': 'system',
        'content':
            'You are a strict grading API. Return exactly one valid JSON object with only this key: results. '
            'results must map each submission alias to an object with scores and comments. '
            'Every result object must have exactly this schema: {"scores": object, "comments": object}. '
            'scores must map every criterion id to an integer. comments must map every criterion id to a Vietnamese string. '
            'Never return comments as a plain string, list, null, or nested object. '
            'Never omit scores or comments for any alias. '
            'Before returning, verify internally that results contains every alias from aliases and every criterionId from criterionIds. '
            'Also verify every score is inside 0..maxScores[criterionId]; never return scores above the criterion max. '
            'If a score/comment is uncertain, still return the key with the best score/comment. Return only JSON. '
            'Do not use Markdown or code fences. '
            'ALLOWED SCORE RANGES (score MUST be within these ranges): $rangeList. '
            'Use maxScores/criterionMaxScores as hard upper bounds for every alias. '
            'Grade every rubric criterion listed in criterionIds exactly once for every submission. Comments must be short Vietnamese reasons. '
            'Use packageContext as authoritative: exam question text, rubric criteria, rubric table level labels, and common mistakes. '
            'Interpret each rubric level by its original table label, including percentages such as 100%, 50-70%, or <50% when present. '
            'Student answers may be organized with labels like Request 1, Request 2, Question 1, or Question 2; treat those sections as the student answer, not as automatic copied-question text. '
            'If a submission copies parts of the exam question, still grade any additional usable answer content and award partial credit when rubric evidence is present. '
            'Student English may be broken; grade the intended project-management content, not grammar or spelling. '
            'Do not mark a criterion zero when the submission has a recognizable attempt related to that criterion; award partial credit instead. '
            'A total score of zero is valid only when the whole submission is blank, unrelated, or unusable. '
            'Each comment must mention the concrete evidence found or the concrete missing requirement. '
            'Grade by semantic content, accept imperfect wording, award partial credit for relevant incomplete answers, and give zero only when missing/unrelated/contradictory.',
      },
      {
        'role': 'user',
        'content': jsonEncode({
          'outputSchema':
              '{"results":{"542":{"scores":{"1.1":2},"comments":{"1.1":"Vietnamese reason."}}}}',
          'aliases': [
            for (final submission in request.submissions) submission.alias,
          ],
          'criterionIds': [
            for (final criterion in request.criteria) criterion.id,
          ],
          'maxScores': maxScores,
          'criterionMaxScores': maxScores,
          'packageContext': request.packageContext,
          'submissions': [
            for (final submission in request.submissions)
              {'alias': submission.alias, 'content': submission.content},
          ],
        }),
      },
    ];

    return {
      'model': model,
      'temperature': AppConstants.aiTemperature,
      'max_completion_tokens': AppConstants.aiMaxTokens,
      'messages': messages,
    };
  }

  String? _messageText(Object? rawContent) {
    if (rawContent is String) {
      return rawContent;
    }
    if (rawContent is List) {
      final buffer = StringBuffer();
      for (final item in rawContent) {
        if (item is Map) {
          final text = item['text'] ?? item['content'];
          if (text is String) {
            buffer.write(text);
          }
        } else if (item is String) {
          buffer.write(item);
        }
      }
      return buffer.toString();
    }
    return null;
  }

  String normalizeAiJsonResponse(String raw) {
    var normalized = raw.trim();
    if (normalized.startsWith('```')) {
      normalized = normalized.substring(3).trimLeft();
      if (normalized.toLowerCase().startsWith('json')) {
        normalized = normalized.substring(4).trimLeft();
      }
      final fenceEnd = normalized.lastIndexOf('```');
      if (fenceEnd >= 0) {
        normalized = normalized.substring(0, fenceEnd).trim();
      }
    }

    final start = normalized.indexOf('{');
    final end = normalized.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const FormatException('No JSON object found.');
    }
    return normalized.substring(start, end + 1).trim();
  }
}

class AiGradingException implements Exception {
  const AiGradingException(this.message);

  final String message;

  @override
  String toString() => message;
}
