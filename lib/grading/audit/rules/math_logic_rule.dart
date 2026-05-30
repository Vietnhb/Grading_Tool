import '../../grading_models.dart';
import '../ai_grading_response.dart';
import '../audit_result.dart';
import '../grading_rule.dart';

class MathLogicRule implements GradingRule {
  @override
  AuditResult evaluate(AIGradingResponse response, GradingGuide guide) {
    int calculatedTotal = 0;
    
    for (final score in response.questionScores) {
      calculatedTotal += score ?? 0;
    }
    
    if (calculatedTotal != response.totalScore) {
      return AuditResult.fail(
        'Math error: Sum of question scores ($calculatedTotal) does not match reported total score (${response.totalScore}).',
      );
    }
    
    return AuditResult.pass();
  }
}
