import 'dart:io';

import 'submission_models.dart';
import '../core/file_name_utils.dart';

class SubmissionParser {
  final Map<String, StudentSubmission> _cache = {};

  Future<StudentSubmission> parse(File file) async {
    final cached = _cache[file.path];
    if (cached != null) return cached;

    final submission = StudentSubmission(
      alias: aliasFromFile(file),
      content: (await file.readAsString()).trim(),
    );
    _cache[file.path] = submission;
    return submission;
  }
}
