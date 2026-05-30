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
      if (entry.value < 0 || entry.value > criterion.maxScore) {
        errors.add(
          'Criterion ${entry.key} score ${entry.value} is outside 0-${criterion.maxScore}.',
        );
        continue;
      }
      criterionScores[entry.key] = entry.value;
      questionTotals[criterion.questionIndex] += entry.value;
    }

    for (final criterion in rubric) {
      if (!result.scores.containsKey(criterion.id)) {
        errors.add('Criterion ${criterion.id} is missing from the AI result.');
      }
      if (!result.comments.containsKey(criterion.id)) {
        warnings.add('Criterion ${criterion.id} has no AI comment.');
      }
    }

    return AiValidationResult(
      accepted: errors.isEmpty,
      questionScores: questionTotals.map<int?>((score) => score).toList(),
      criterionScores: criterionScores,
      errors: errors,
      warnings: warnings,
    );
  }
}
