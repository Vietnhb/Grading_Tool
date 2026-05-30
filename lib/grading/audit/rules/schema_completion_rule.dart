import '../../grading_models.dart';
import '../ai_grading_response.dart';
import '../audit_result.dart';
import '../grading_rule.dart';

class SchemaCompletionRule implements GradingRule {
  @override
  AuditResult evaluate(AIGradingResponse response, GradingGuide guide) {
    // Assuming maxScores contains entries for all questions (0 to N-1)
    // We can infer the expected number of questions from it.
    if (guide.maxScores.isEmpty) {
      return AuditResult.pass(); // Cannot validate if guide has no scores
    }
    
    final expectedQuestionCount = guide.maxScores.keys.reduce((a, b) => a > b ? a : b) + 1;
    
    if (response.questionScores.length != expectedQuestionCount) {
      return AuditResult.fail(
        'Missing questions: AI returned ${response.questionScores.length} scores, but guide expects $expectedQuestionCount.',
      );
    }
    
    for (var i = 0; i < response.questionScores.length; i++) {
      if (response.questionScores[i] == null) {
        return AuditResult.fail('Question ${i + 1} has a null score.');
      }
    }
    
    return AuditResult.pass();
  }
}
