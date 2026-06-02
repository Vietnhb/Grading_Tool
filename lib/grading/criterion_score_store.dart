import 'dart:convert';
import 'dart:io';

import 'ai_grading_service.dart';
import 'grading_models.dart';

class CriterionScoreStore {
  const CriterionScoreStore();

  Future<Map<String, Map<String, int?>>> load({
    required Directory packageDirectory,
    required Iterable<String> aliases,
    required Iterable<AiRubricCriterion> criteria,
  }) async {
    final aliasSet = aliases.toSet();
    final criterionIds = criteria.map((criterion) => criterion.id).toSet();
    return _readAudit(packageDirectory, aliasSet, criterionIds);
  }

  Future<Map<String, AiGradeSuggestion>> loadAiSuggestions({
    required Directory packageDirectory,
    required Iterable<String> aliases,
    required Iterable<AiRubricCriterion> criteria,
  }) async {
    final aliasSet = aliases.toSet();
    final criterionIds = criteria.map((criterion) => criterion.id).toSet();
    final file = _auditFile(packageDirectory);
    if (!await file.exists()) {
      return {};
    }

    final suggestions = <String, AiGradeSuggestion>{};
    try {
      final lines = await file.readAsLines();
      for (final line in lines) {
        if (line.trim().isEmpty) {
          continue;
        }
        final record = jsonDecode(line);
        if (record is! Map<String, Object?> || record['status'] != 'accepted') {
          continue;
        }
        final source = record['source']?.toString();
        if (source != null && source != 'ai') {
          continue;
        }
        final alias = record['alias'];
        if (alias is! String || !aliasSet.contains(alias)) {
          continue;
        }
        final suggestion = _aiSuggestionFrom(record, criterionIds);
        if (suggestion != null) {
          suggestions[alias] = suggestion;
        }
      }
    } catch (_) {
      return {};
    }
    return suggestions;
  }

  Future<void> appendTeacherSave({
    required Directory packageDirectory,
    required GradingEntry entry,
    required Map<String, int?> criterionScores,
  }) async {
    final record = <String, Object?>{
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'alias': entry.alias,
      'source': 'teacher',
      'status': 'saved',
      'questionScores': entry.requestScores,
      'criterionScores': criterionScores,
      'totalScore': entry.total,
      'comment': entry.comment,
    };

    await _auditFile(packageDirectory).writeAsString(
      '${jsonEncode(record)}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  Future<Map<String, Map<String, int?>>> _readAudit(
    Directory packageDirectory,
    Set<String> aliases,
    Set<String> criterionIds,
  ) async {
    final file = _auditFile(packageDirectory);
    if (!await file.exists()) {
      return {};
    }

    final aiScoresByAlias = <String, Map<String, int?>>{};
    final teacherScoresByAlias = <String, Map<String, int?>>{};
    try {
      final lines = await file.readAsLines();
      for (final line in lines) {
        if (line.trim().isEmpty) {
          continue;
        }
        final record = jsonDecode(line);
        if (record is! Map<String, Object?>) {
          continue;
        }
        final alias = record['alias'];
        if (alias is! String || !aliases.contains(alias)) {
          continue;
        }

        final source = record['source']?.toString();
        if (source == 'teacher' && record['status'] == 'saved') {
          final rawScores = record['criterionScores'];
          if (rawScores is Map<String, Object?>) {
            teacherScoresByAlias[alias] = _parseScoreMap(rawScores);
          }
          continue;
        }

        if ((source == null || source == 'ai') &&
            record['status'] == 'accepted') {
          final rawScores = _aiScoresFrom(record);
          if (rawScores != null) {
            aiScoresByAlias[alias] = _parseScoreMap(rawScores);
          }
        }
      }
    } catch (_) {
      return {};
    }

    return _filterScores(
      {...aiScoresByAlias, ...teacherScoresByAlias},
      aliases,
      criterionIds,
    );
  }

  Map<String, Object?>? _aiScoresFrom(Map<String, Object?> record) {
    final criterionScores = record['criterionScores'];
    if (criterionScores is Map<String, Object?>) {
      return criterionScores;
    }
    final rawResponse = record['rawAiResponse'];
    if (rawResponse is! Map<String, Object?>) {
      return null;
    }
    final rawScores = rawResponse['scores'];
    return rawScores is Map<String, Object?> ? rawScores : null;
  }

  AiGradeSuggestion? _aiSuggestionFrom(
    Map<String, Object?> record,
    Set<String> criterionIds,
  ) {
    final rawScores = _aiScoresFrom(record);
    if (rawScores == null) {
      return null;
    }
    final questionScores = _parseQuestionScores(record['questionScores']);
    if (questionScores.isEmpty) {
      return null;
    }
    return AiGradeSuggestion(
      questionScores: questionScores,
      criterionScores: _filterScoreMap(_parseScoreMap(rawScores), criterionIds),
      comments: _parseComments(record),
      warnings: _parseStringList(record['warnings']),
    );
  }

  List<int?> _parseQuestionScores(Object? rawScores) {
    if (rawScores is! List<Object?>) {
      return const [];
    }
    return rawScores
        .map(
          (score) => score == null
              ? null
              : score is num
              ? score.round()
              : int.tryParse(score.toString()),
        )
        .toList();
  }

  Map<String, String> _parseComments(Map<String, Object?> record) {
    final rawResponse = record['rawAiResponse'];
    if (rawResponse is! Map<String, Object?>) {
      return const {};
    }
    final rawComments = rawResponse['comments'];
    if (rawComments is! Map<String, Object?>) {
      return const {};
    }
    return {
      for (final entry in rawComments.entries)
        entry.key: entry.value?.toString() ?? '',
    };
  }

  List<String> _parseStringList(Object? rawValues) {
    if (rawValues is! List<Object?>) {
      return const [];
    }
    return [
      for (final value in rawValues)
        if (value != null) value.toString(),
    ];
  }

  Map<String, int?> _parseScoreMap(Map<String, Object?> rawScores) {
    final scores = <String, int?>{};
    for (final entry in rawScores.entries) {
      final value = entry.value;
      scores[entry.key] = value == null
          ? null
          : value is num
          ? value.round()
          : int.tryParse(value.toString());
    }
    return scores;
  }

  Map<String, Map<String, int?>> _filterScores(
    Map<String, Map<String, int?>> rawScores,
    Set<String> aliases,
    Set<String> criterionIds,
  ) {
    final scoresByAlias = <String, Map<String, int?>>{};
    for (final aliasEntry in rawScores.entries) {
      if (!aliases.contains(aliasEntry.key)) {
        continue;
      }
      final scores = <String, int?>{};
      scores.addAll(_filterScoreMap(aliasEntry.value, criterionIds));
      if (scores.isNotEmpty) {
        scoresByAlias[aliasEntry.key] = scores;
      }
    }
    return scoresByAlias;
  }

  Map<String, int?> _filterScoreMap(
    Map<String, int?> scores,
    Set<String> criterionIds,
  ) {
    return {
      for (final scoreEntry in scores.entries)
        if (criterionIds.contains(scoreEntry.key))
          scoreEntry.key: scoreEntry.value,
    };
  }

  File _auditFile(Directory packageDirectory) {
    return File(
      '${packageDirectory.path}${Platform.pathSeparator}ai_grading_audit.jsonl',
    );
  }
}
