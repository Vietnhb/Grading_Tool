import 'dart:convert';
import 'dart:io';

import '../submission/submission_models.dart';
import 'ai_grading_service.dart';
import 'ai_grading_validator.dart';

class AiGradingAuditLog {
  const AiGradingAuditLog();

  Future<void> saveAi({
    required Directory packageDirectory,
    required StudentSubmission submission,
    required String model,
    required AiGradingResult? rawResult,
    required AiValidationResult? validation,
    Object? error,
  }) async {
    final audit = await _readAudit(packageDirectory);
    final record = Map<String, Object?>.from(
      audit[submission.alias] ?? const {},
    );
    record['ai'] = {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'model': model,
      'status': error == null && validation?.accepted == true
          ? 'accepted'
          : error == null
          ? 'rejected'
          : 'failed',
      'questionScores': validation?.questionScores,
      'criterionScores': validation?.criterionScores,
      'errors': validation?.errors,
      'warnings': validation?.warnings,
      'rawAiResponse': rawResult?.toJson(),
      'error': error?.toString(),
    };
    audit[submission.alias] = record;
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

  File _auditFile(Directory packageDirectory) {
    return File(
      '${packageDirectory.path}${Platform.pathSeparator}grading_log.json',
    );
  }
}
