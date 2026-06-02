import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/app_exception.dart';
import '../core/constants.dart';
import '../core/file_name_utils.dart';
import 'submission_models.dart';

class PackageDetector {
  Future<ExamPackage> detect(String path) async {
    // Kiem tra folder package dau vao. Ham nay chi tra ve ExamPackage
    // khi folder co du: xlsx, docx, anh de va Student_Solutions/*.txt.
    final root = Directory(path);
    if (!await root.exists()) {
      throw const AppException('Please Select Exam package folder.');
    }

    final rootFiles = await _files(root);
    final solutions = Directory(
      p.join(root.path, AppConstants.studentSolutionsFolder),
    );
    if (!solutions.existsSync()) {
      throw AppException(
        '${AppConstants.studentSolutionsFolder} folder not found.',
      );
    }

    final studentFiles =
        (await _files(solutions))
            .where(
              (file) => extensionOf(file) == AppConstants.submissionExtension,
            )
            .toList()
          ..sort((a, b) => compareAliases(aliasFromFile(a), aliasFromFile(b)));
    // Sau khi co danh sach file .txt, controller se dung alias cua tung file
    // de map voi dong tuong ung trong Excel.
    if (studentFiles.isEmpty) {
      throw AppException(
        'No ${AppConstants.submissionExtension} files found in ${AppConstants.studentSolutionsFolder}.',
      );
    }

    return ExamPackage(
      rootDirectory: root,
      markSheetFile: _single(
        rootFiles,
        (file) => {AppConstants.markInputExtension}.contains(extensionOf(file)),
        'No ${AppConstants.markInputExtension} mark input file was found.',
        'More than one ${AppConstants.markInputExtension} mark input file was found.',
      ),
      studentFiles: studentFiles,
      gradingGuideFile: _single(
        rootFiles,
        (file) => extensionOf(file) == AppConstants.gradingGuideExtension,
        'No ${AppConstants.gradingGuideExtension} grading guide was found.',
        'More than one ${AppConstants.gradingGuideExtension} grading guide was found.',
      ),
      questionImageFile: _single(
        rootFiles,
        (file) =>
            AppConstants.supportedImageExtensions.contains(extensionOf(file)),
        'No question image was found.',
        'More than one question image was found.',
      ),
    );
  }

  Future<List<File>> _files(Directory directory) => directory
      .list(followLinks: false)
      .where((entity) => entity is File)
      .cast<File>()
      .toList();

  File _single(
    List<File> files,
    bool Function(File file) test,
    String missing,
    String duplicated,
  ) {
    // Tim dung 1 file khop dieu kien. Thieu hoac bi trung thi bao loi ro rang.
    final matches = files.where(test).toList();
    if (matches.isEmpty) throw AppException(missing);
    if (matches.length > 1) throw AppException(duplicated);
    return matches.single;
  }
}
