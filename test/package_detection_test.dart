import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_grading_tool/grading/grading_models.dart';
import 'package:lecturer_grading_tool/grading/excel_grade_repository.dart';
import 'package:lecturer_grading_tool/document/docx_parser.dart';
import 'package:lecturer_grading_tool/submission/package_detector.dart';
import 'package:lecturer_grading_tool/core/file_name_utils.dart';

void main() {
  test('detects provided exam package and mark sheet layout', () async {
    final package = await PackageDetector().detect('examPakage');
    final aliases = package.studentFiles.take(3).map(aliasFromFile).toList();
    final entries = await ExcelGradeRepository().open(
      package.markSheetFile,
      aliases,
    );

    expect(package.markSheetFile.existsSync(), isTrue);
    expect(package.studentFiles.length, greaterThan(100));
    expect(entries.keys, containsAll(aliases));
  });

  test('parses provided grading guide as structured docx blocks', () async {
    final package = await PackageDetector().detect('examPakage');
    final guide = await const DocxTextReader().read(package.gradingGuideFile);

    expect(guide.blocks, isNotEmpty);
    expect(
      guide.blocks.whereType<SectionBlock>().length,
      greaterThanOrEqualTo(1),
    );
    expect(_containsRubricTable(guide.blocks), isTrue);
    expect(_containsBulletList(guide.blocks), isTrue);
  });
}

bool _containsRubricTable(List<DocumentBlock> blocks) {
  for (final block in blocks) {
    if (block is RubricTableBlock) {
      return true;
    }
    if (block is SectionBlock && _containsRubricTable(block.children)) {
      return true;
    }
  }
  return false;
}

bool _containsBulletList(List<DocumentBlock> blocks) {
  for (final block in blocks) {
    if (block is BulletListBlock) {
      return true;
    }
    if (block is SectionBlock && _containsBulletList(block.children)) {
      return true;
    }
  }
  return false;
}
