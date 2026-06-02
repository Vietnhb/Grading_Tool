import 'ai_grading_service.dart';

class AiValidationResult {
  const AiValidationResult({
    required this.accepted,
    required this.questionScores,
    required this.criterionScores,
    required this.errors,
    required this.warnings,
  });

  final bool accepted;
  final List<int?> questionScores;
  final Map<String, int?> criterionScores;
  final List<String> errors;
  final List<String> warnings;
}

class AiGradingValidator {
  const AiGradingValidator();

  AiValidationResult validate({
    required AiGradingResult result,
    required List<AiRubricCriterion> rubric,
    required int questionCount,
    required String submissionContent,
  }) {
    final errors = <String>[];
    final warnings = <String>[];
    final criteriaById = {
      for (final criterion in rubric) criterion.id: criterion,
    };
    final criterionScores = <String, int?>{};
    final questionTotals = List<int>.filled(questionCount, 0);

    for (final entry in result.scores.entries) {
      final criterion = criteriaById[entry.key];
      if (criterion == null) {
        errors.add('Criterion ${entry.key} is not defined in the rubric.');
        continue;
      }
      var score = entry.value;
      if (score < 0) {
        warnings.add(
          'Criterion ${entry.key}: AI returned ${entry.value}; clamped to 0.',
        );
        score = 0;
      } else if (score > criterion.maxScore) {
        warnings.add(
          'Criterion ${entry.key}: AI returned ${entry.value}; clamped to ${criterion.maxScore}.',
        );
        score = criterion.maxScore;
      }
      criterionScores[entry.key] = score;
      questionTotals[criterion.questionIndex] += score;
    }

    for (final criterion in rubric) {
      if (!result.scores.containsKey(criterion.id)) {
        errors.add('Criterion ${criterion.id} is missing from the AI result.');
      }
      if (!result.comments.containsKey(criterion.id)) {
        warnings.add('Criterion ${criterion.id} has no AI comment.');
      }
    }

    final totalScore = questionTotals.fold(0, (sum, score) => sum + score);
    if (errors.isEmpty &&
        totalScore == 0 &&
        _hasSubstantialAnswer(submissionContent)) {
      errors.add(
        'AI returned all zero scores for a non-empty/substantial submission. Regrade or review manually.',
      );
    }

    return AiValidationResult(
      accepted: errors.isEmpty,
      questionScores: questionTotals.map<int?>((score) => score).toList(),
      criterionScores: criterionScores,
      errors: errors,
      warnings: warnings,
    );
  }

  bool _hasSubstantialAnswer(String content) {
    final normalized = content.trim();
    if (normalized.length < 200) {
      return false;
    }
    return RegExp(
      r'\b(request|question|risk|cost|budget|project|raci)\b',
      caseSensitive: false,
    ).hasMatch(normalized);
  }
}
