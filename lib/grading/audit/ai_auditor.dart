import '../grading_models.dart';
import 'ai_grading_response.dart';
import 'audit_result.dart';
import 'grading_rule.dart';

class AIAuditor {
  final List<GradingRule> rules;

  const AIAuditor({required this.rules});

  AuditResult audit(AIGradingResponse response, GradingGuide guide) {
    for (final rule in rules) {
      final result = rule.evaluate(response, guide);
      if (!result.isValid) {
        return result; // Fail fast on the first error
      }
    }
    return AuditResult.pass();
  }
}
