import '../grading_models.dart';
import 'ai_grading_response.dart';
import 'audit_result.dart';

abstract class GradingRule {
  AuditResult evaluate(AIGradingResponse response, GradingGuide guide);
}
