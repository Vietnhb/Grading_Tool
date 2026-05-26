import 'dart:io';

class ExamPackage {
  const ExamPackage({
    required this.rootDirectory,
    required this.markSheetFile,
    required this.studentFiles,
    required this.gradingGuideFile,
    required this.questionImageFile,
  });

  final Directory rootDirectory;
  final File markSheetFile;
  final List<File> studentFiles;
  final File gradingGuideFile;
  final File questionImageFile;
}

class StudentSubmission {
  const StudentSubmission({required this.alias, required this.content});

  final String alias;
  final String content;
}
