import 'dart:convert';
import 'dart:io';

import '../submission/submission_models.dart';
import 'grading_models.dart';

const _aiRequestTimeout = Duration(seconds: 90);

class AiRubricCriterion {
  const AiRubricCriterion({
    required this.id,
    required this.title,
    required this.maxScore,
    required this.questionIndex,
    this.fullCreditDescription = '',
    this.partialCreditDescription = '',
    this.poorCreditDescription = '',
    this.commonMistakes = const [],
  });

  final String id;
  final String title;
  final int maxScore;
  final int questionIndex;
  final String fullCreditDescription;
  final String partialCreditDescription;
  final String poorCreditDescription;
  final List<String> commonMistakes;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'maxScore': maxScore,
    'questionIndex': questionIndex,
    'fullCreditDescription': fullCreditDescription,
    'partialCreditDescription': partialCreditDescription,
    'poorCreditDescription': poorCreditDescription,
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
      buffer.write(' | full: $fullCreditDescription');
    }
    if (partialCreditDescription.isNotEmpty) {
      buffer.write(' | partial: $partialCreditDescription');
    }
    if (poorCreditDescription.isNotEmpty) {
      buffer.write(' | poor: $poorCreditDescription');
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
      commonMistakes: description.commonMistakes,
    );
  }

  Map<String, _RubricDescription> _rubricRowsById(GradingGuide guide) {
    final rowsById = <String, _RubricDescription>{};
    final mistakes = <String>[];
    _collectRubricRows(guide.blocks, rowsById, mistakes);
    if (mistakes.isNotEmpty) {
      return {
        for (final entry in rowsById.entries)
          entry.key: entry.value.copyWith(commonMistakes: mistakes),
      };
    }
    return rowsById;
  }

  void _collectRubricRows(
    List<DocumentBlock> blocks,
    Map<String, _RubricDescription> rowsById,
    List<String> mistakes,
  ) {
    var collectingMistakes = false;
    for (final block in blocks) {
      switch (block) {
        case SectionBlock(:final children):
          _collectRubricRows(children, rowsById, mistakes);
        case RubricTableBlock(:final rows):
          for (final row in rows) {
            final description = _descriptionFromRow(row);
            if (description != null) {
              rowsById[description.id] = description;
            }
          }
          collectingMistakes = false;
        case ParagraphBlock(:final text):
          final normalized = text.toLowerCase();
          if (normalized.contains('lỗi thường gặp')) {
            collectingMistakes = true;
          } else if (collectingMistakes && text.trim().isNotEmpty) {
            mistakes.add(text.trim());
          }
        case BulletListBlock(:final items):
          if (collectingMistakes) {
            mistakes.addAll(items.map((item) => item.text.trim()));
          }
      }
    }
  }

  _RubricDescription? _descriptionFromRow(RubricTableRowBlock row) {
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

class _RubricDescription {
  const _RubricDescription({
    required this.id,
    required this.title,
    required this.maxScore,
    required this.fullCreditDescription,
    required this.partialCreditDescription,
    required this.poorCreditDescription,
    this.commonMistakes = const [],
  });

  final String id;
  final String title;
  final int? maxScore;
  final String fullCreditDescription;
  final String partialCreditDescription;
  final String poorCreditDescription;
  final List<String> commonMistakes;

  _RubricDescription copyWith({List<String>? commonMistakes}) {
    return _RubricDescription(
      id: id,
      title: title,
      maxScore: maxScore,
      fullCreditDescription: fullCreditDescription,
      partialCreditDescription: partialCreditDescription,
      poorCreditDescription: poorCreditDescription,
      commonMistakes: commonMistakes ?? this.commonMistakes,
    );
  }
}

class OpenRouterGradingService {
  OpenRouterGradingService({
    HttpClient? httpClient,
    String? apiKey,
    this.model = 'openai/gpt-oss-120b:free',
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
        ? 'openai/gpt-oss-120b:free'
        : model.trim();
  }

  void clearApiKey() => _apiKey = null;

  void setModel(String model) {
    final trimmed = model.trim();
    this.model = trimmed.isEmpty
        ? 'openai/gpt-oss-120b:free'
        : trimmed;
  }

  Future<AiGradingResult> grade(AiGradingRequest request) async {
    final apiKey = _apiKey;
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const AiGradingException(
        'OPENROUTER_API_KEY is not set. Add it in AI Settings before using OpenRouter.',
      );
    }
    // Perform request and parse result. If OpenRouter returns a model endpoint
    // not found error, attempt retrying with fallback models from
    // OPENROUTER_MODEL_FALLBACKS (comma-separated) if provided.
    Future<AiGradingResult> _attempt(String currentModel) async {
      // Temporarily set model for payload generation
      final originalModel = model;
      try {
        model = currentModel;
        final httpRequest = await _httpClient.postUrl(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        );
        httpRequest.headers
          ..contentType = ContentType.json
          ..set(HttpHeaders.authorizationHeader, 'Bearer $apiKey')
          ..set('HTTP-Referer', 'http://localhost/lecturer-grading-tool')
          ..set('X-Title', 'Lecturer Grading Tool');
        httpRequest.write(jsonEncode(_payloadFor(request)));

        final response = await httpRequest.close().timeout(_aiRequestTimeout);
        final body = await utf8.decodeStream(response);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw AiGradingException('OpenRouter request failed: $body');
        }

        final decoded = jsonDecode(body) as Map<String, Object?>;
        final choices = decoded['choices'];
        if (choices is! List || choices.isEmpty || choices.first is! Map) {
          throw const AiGradingException(
            'OpenRouter response did not contain choices.',
          );
        }
        final message = (choices.first as Map)['message'];
        if (message is! Map || message['content'] is! String) {
          throw const AiGradingException(
            'OpenRouter response did not contain content.',
          );
        }

        final decodedJson = jsonDecode(
          normalizeAiJsonResponse(message['content'] as String),
        );
        if (decodedJson is! Map<String, dynamic>) {
          throw const AiGradingException(
            'AI output is not a JSON object. No score was applied.',
          );
        }
        return AiGradingResult.fromJson(decodedJson);
      } finally {
        model = originalModel;
      }
    }

    try {
      return await _attempt(model);
    } on AiGradingException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('no endpoints found') || msg.contains('404')) {
        final fallbacks = (Platform.environment['OPENROUTER_MODEL_FALLBACKS'] ?? '')
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        for (final fb in fallbacks) {
          try {
            stdout.writeln('Model ${model} unavailable — trying fallback $fb');
            return await _attempt(fb);
          } catch (_) {
            // continue to next fallback
          }
        }
        throw AiGradingException(
            'Model ${model} not available and no fallback succeeded. ${e.message}');
      }
      rethrow;
    }
  }

  Map<String, Object?> _payloadFor(AiGradingRequest request) {
    return {
      'model': model,
      'response_format': {'type': 'json_object'},
      'temperature': 0,
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a strict grading API. Return exactly one valid JSON object and nothing else. '
              'Do not use Markdown. Do not wrap the JSON in code fences. '
              'Do not return multiple JSON objects. Do not add trailing commas. '
              'The top-level JSON object must contain exactly these keys: scores, comments. '
              'Grade every rubric criterion exactly once. Scores must be integers and must not exceed maxScore. '
              'Use the cached package context and rubric to decide each score. '
              'If the answer only matches partialCreditDescription, do not give full score.',
        },
        {
          'role': 'user',
          'content': jsonEncode({
            'requiredJsonShape':
                '{"scores":{"1.1":2,"1.2":3},"comments":{"1.1":"Short reason.","1.2":"Short reason."}}',
            'rules': [
              'Return one valid JSON object only.',
              'scores must contain every rubric criterion id exactly once.',
              'comments must contain a short grading reason for every rubric criterion id.',
              'The rubric and question context are already cached in packageContext.',
              'If the submission satisfies fullCreditDescription, give maxScore.',
              'If the submission only satisfies partialCreditDescription, give a middle score.',
              'If the submission matches poorCreditDescription, give low score or zero.',
              'Never give maxScore for an answer that only satisfies partialCreditDescription.',
            ],
            'packageContext': request.packageContext,
            'submission': {
              'alias': request.submission.alias,
              'content': request.submission.content,
            },
            'questionCount': request.questionCount,
          }),
        },
      ],
    };
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
