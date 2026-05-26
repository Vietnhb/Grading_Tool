import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_grading_tool/grading/grading_models.dart';
import 'package:lecturer_grading_tool/document/docx_parser.dart';
import 'package:xml/xml.dart';

void main() {
  test('parses docx xml structure into guide blocks', () {
    final document = XmlDocument.parse('''
<?xml version="1.0" encoding="UTF-8"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr><w:pStyle w:val="Heading1"/></w:pPr>
      <w:r><w:t>Rubric</w:t></w:r>
    </w:p>
    <w:p>
      <w:r><w:t>General grading guidance.</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr>
        <w:pStyle w:val="ListParagraph"/>
        <w:numPr><w:ilvl w:val="0"/><w:numId w:val="9"/></w:numPr>
      </w:pPr>
      <w:r><w:t>Check formatting.</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr>
        <w:pStyle w:val="ListParagraph"/>
        <w:numPr><w:ilvl w:val="1"/><w:numId w:val="9"/></w:numPr>
      </w:pPr>
      <w:r><w:t>Check indentation.</w:t></w:r>
    </w:p>
    <w:tbl>
      <w:tblPr><w:tblLook w:firstRow="1"/></w:tblPr>
      <w:tr>
        <w:tc><w:p><w:r><w:t>Criterion</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>Points</w:t></w:r></w:p></w:tc>
      </w:tr>
      <w:tr>
        <w:tc><w:p><w:r><w:t>Project charter</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>20</w:t></w:r></w:p></w:tc>
      </w:tr>
    </w:tbl>
    <w:p>
      <w:pPr><w:pStyle w:val="Heading2"/></w:pPr>
      <w:r><w:t>Details</w:t></w:r>
    </w:p>
    <w:p>
      <w:r><w:t>Nested paragraph.</w:t></w:r>
    </w:p>
  </w:body>
</w:document>
''');

    final guide = DocxDocumentParser().parse(document);

    expect(guide.blocks, hasLength(1));
    final rubric = guide.blocks.single as SectionBlock;
    expect(rubric.heading.text, 'Rubric');
    expect(rubric.heading.level, 1);
    expect(rubric.children, hasLength(4));

    expect(
      (rubric.children[0] as ParagraphBlock).text,
      'General grading guidance.',
    );

    final list = rubric.children[1] as BulletListBlock;
    expect(list.numberingId, '9');
    expect(list.items.map((item) => item.text), [
      'Check formatting.',
      'Check indentation.',
    ]);
    expect(list.items.last.level, 1);

    final table = rubric.children[2] as RubricTableBlock;
    expect(table.rows.first.isHeader, isTrue);
    expect(table.rows.first.cells, ['Criterion', 'Points']);
    expect(table.rows.last.cells, ['Project charter', '20']);

    final details = rubric.children[3] as SectionBlock;
    expect(details.heading.level, 2);
    expect(
      (details.children.single as ParagraphBlock).text,
      'Nested paragraph.',
    );
  });
}
