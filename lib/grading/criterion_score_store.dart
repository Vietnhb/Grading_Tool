import 'dart:convert';
import 'dart:io';

import '../core/constants.dart';
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
    final audit = await _readAudit(packageDirectory);
    final scoresByAlias = <String, Map<String, int?>>{};

    for (final alias in aliasSet) {
      final record = audit[alias];
      if (record == null) {
        continue;
      }

      final teacherScores = _scoresFromBranch(record['teacher']);
      if (teacherScores == null) {
        continue;
      }

      final filtered = _filterScoreMap(teacherScores, criterionIds);
      if (filtered.isNotEmpty) {
        scoresByAlias[alias] = filtered;
      }
    }

    return scoresByAlias;
  }

  Future<Map<String, AiGradeSuggestion>> loadAiSuggestions({
    required Directory packageDirectory,
    required Iterable<String> aliases,
    required Iterable<AiRubricCriterion> criteria,
  }) async {
    final aliasSet = aliases.toSet();
    final criterionIds = criteria.map((criterion) => criterion.id).toSet();
    final audit = await _readAudit(packageDirectory);
    final suggestions = <String, AiGradeSuggestion>{};

    for (final alias in aliasSet) {
      final aiBranch = audit[alias]?['ai'];
      if (aiBranch is! Map || aiBranch['status'] != 'accepted') {
        continue;
      }

      final suggestion = _aiSuggestionFrom(
        Map<String, Object?>.from(aiBranch),
        criterionIds,
      );
      if (suggestion != null) {
        suggestions[alias] = suggestion;
      }
    }

    return suggestions;
  }

  Future<void> saveTeacher({
    required Directory packageDirectory,
    required GradingEntry entry,
    required Map<String, int?> criterionScores,
  }) async {
    final audit = await _readAudit(packageDirectory);
    final record = Map<String, Object?>.from(audit[entry.alias] ?? const {});
    record['teacher'] = {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'status': 'saved',
      'questionScores': entry.requestScores,
      'criterionScores': criterionScores,
      'totalScore': entry.total,
      'comment': entry.comment,
    };
    audit[entry.alias] = record;
    await _writeAudit(packageDirectory, audit);
  }

  Future<Map<String, Map<String, Object?>>> _readAudit(
    Directory packageDirectory,
  ) async {
    final file = _auditFile(packageDirectory);
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          return {
            for (final entry in decoded.entries)
              if (entry.value is Map)
                entry.key.toString(): Map<String, Object?>.from(
                  entry.value as Map,
                ),
          };
        }
      } catch (_) {
        return {};
      }
    }

    return {};
  }

  Future<void> _writeAudit(
    Directory packageDirectory,
    Map<String, Map<String, Object?>> audit,
  ) async {
    await _auditFile(packageDirectory).writeAsString(
      const JsonEncoder.withIndent('  ').convert(audit),
      flush: true,
    );
  }

  Map<String, int?>? _scoresFromBranch(Object? branch) {
    if (branch is! Map) {
      return null;
    }
    final typedBranch = Map<String, Object?>.from(branch);
    final rawScores = typedBranch['criterionScores'];
    if (rawScores is Map) {
      return _parseScoreMap(rawScores);
    }
    final rawResponse = typedBranch['rawAiResponse'];
    if (rawResponse is! Map) {
      return null;
    }
    final responseScores = rawResponse['scores'];
    return responseScores is Map ? _parseScoreMap(responseScores) : null;
  }

  AiGradeSuggestion? _aiSuggestionFrom(
    Map<String, Object?> branch,
    Set<String> criterionIds,
  ) {
    final rawScores = _scoresFromBranch(branch);
    if (rawScores == null) {
      return null;
    }
    final questionScores = _parseQuestionScores(branch['questionScores']);
    if (questionScores.isEmpty) {
      return null;
    }
    final warnings = _parseStringList(branch['warnings']);
    if (_isSuspiciousAllZero(questionScores, warnings)) {
      return null;
    }
    return AiGradeSuggestion(
      questionScores: questionScores,
      criterionScores: _filterScoreMap(rawScores, criterionIds),
      comments: _parseComments(branch),
      warnings: warnings,
    );
  }

  bool _isSuspiciousAllZero(List<int?> questionScores, List<String> warnings) {
    final allZero =
        questionScores.isNotEmpty &&
        questionScores.every((score) => score != null && score == 0);
    return allZero;
  }

  List<int?> _parseQuestionScores(Object? rawScores) {
    if (rawScores is! List) {
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

  Map<String, String> _parseComments(Map<String, Object?> branch) {
    final rawResponse = branch['rawAiResponse'];
    if (rawResponse is! Map) {
      return const {};
    }
    final rawComments = rawResponse['comments'];
    if (rawComments is! Map) {
      return const {};
    }
    return {
      for (final entry in rawComments.entries)
        entry.key.toString(): entry.value?.toString() ?? '',
    };
  }

  List<String> _parseStringList(Object? rawValues) {
    if (rawValues is! List) {
      return const [];
    }
    return [
      for (final value in rawValues)
        if (value != null) value.toString(),
    ];
  }

  Map<String, int?> _parseScoreMap(Map rawScores) {
    final scores = <String, int?>{};
    for (final entry in rawScores.entries) {
      final value = entry.value;
      scores[entry.key.toString()] = value == null
          ? null
          : value is num
          ? value.round()
          : int.tryParse(value.toString());
    }
    return scores;
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
      '${packageDirectory.path}${Platform.pathSeparator}${AppConstants.gradingAuditFileName}',
    );
  }
}
