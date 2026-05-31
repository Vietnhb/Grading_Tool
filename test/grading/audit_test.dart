import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_grading_tool/grading/audit/ai_auditor.dart';
import 'package:lecturer_grading_tool/grading/audit/ai_grading_response.dart';
import 'package:lecturer_grading_tool/grading/audit/rules/math_logic_rule.dart';
import 'package:lecturer_grading_tool/grading/audit/rules/schema_completion_rule.dart';
import 'package:lecturer_grading_tool/grading/audit/rules/score_limit_rule.dart';
import 'package:lecturer_grading_tool/grading/grading_models.dart';

void main() {
  group('AIAuditor Tests', () {
    late AIAuditor auditor;
    late GradingGuide guide;

    setUp(() {
      auditor = AIAuditor(rules: [
        SchemaCompletionRule(),
        ScoreLimitRule(),
        MathLogicRule(),
      ]);

      guide = const GradingGuide(
        [],
        maxScores: {0: 5, 1: 3, 2: 2}, // Total 10 points
      );
    });

    test('Valid response should pass', () {
      final response = const AIGradingResponse(
        questionScores: [4, 3, 2],
        totalScore: 9,
        comment: 'Good job',
      );

      final result = auditor.audit(response, guide);
      expect(result.isValid, isTrue);
      expect(result.errorMessage, isNull);
    });

    test('Score limit exceeded should fail', () {
      final response = const AIGradingResponse(
        questionScores: [6, 3, 2], // 6 > max(5)
        totalScore: 11,
        comment: 'Exceed',
      );

      final result = auditor.audit(response, guide);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('exceeds maximum allowed'));
    });

    test('Math logic error should fail', () {
      final response = const AIGradingResponse(
        questionScores: [4, 3, 2],
        totalScore: 10, // 4+3+2 = 9, not 10
        comment: 'Math wrong',
      );

      final result = auditor.audit(response, guide);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('Sum of question scores'));
    });

    test('Missing question score should fail', () {
      final response = const AIGradingResponse(
        questionScores: [4, 3], // missing 3rd question
        totalScore: 7,
        comment: 'Missing',
      );

      final result = auditor.audit(response, guide);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('Missing questions'));
    });
  });
}
