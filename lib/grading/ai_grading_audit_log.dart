import 'dart:convert';
import 'dart:io';

import '../submission/submission_models.dart';
import 'ai_grading_service.dart';
import 'ai_grading_validator.dart';

class AiGradingAuditLog {
  const AiGradingAuditLog();

  Future<void> append({
    required Directory packageDirectory,
    required StudentSubmission submission,
    required String model,
    required AiGradingResult? rawResult,
    required AiValidationResult? validation,
    Object? error,
  }) async {
    final file = File(
      '${packageDirectory.path}${Platform.pathSeparator}ai_grading_audit.jsonl',
    );
    final record = <String, Object?>{
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'alias': submission.alias,
      'model': model,
      'status': error == null && validation?.accepted == true
          ? 'accepted'
          : error == null
          ? 'rejected'
          : 'failed',
      'questionScores': validation?.questionScores,
      'errors': validation?.errors,
      'warnings': validation?.warnings,
      'rawAiResponse': rawResult?.toJson(),
      'error': error?.toString(),
    };

    await file.writeAsString(
      '${jsonEncode(record)}\n',
      mode: FileMode.append,
      flush: true,
    );
  }
}
