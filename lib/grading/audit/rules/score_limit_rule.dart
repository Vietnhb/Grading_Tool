import '../../grading_models.dart';
import '../ai_grading_response.dart';
import '../audit_result.dart';
import '../grading_rule.dart';

class ScoreLimitRule implements GradingRule {
  @override
  AuditResult evaluate(AIGradingResponse response, GradingGuide guide) {
    for (var i = 0; i < response.questionScores.length; i++) {
      final score = response.questionScores[i];
      final maxScore = guide.maxScores[i];
      
      if (score != null && maxScore != null && score > maxScore) {
        return AuditResult.fail(
          'Question ${i + 1} score ($score) exceeds maximum allowed ($maxScore).',
        );
      }
      
      if (score != null && score < 0) {
        return AuditResult.fail(
          'Question ${i + 1} score ($score) cannot be negative.',
        );
      }
    }
    return AuditResult.pass();
  }
}
