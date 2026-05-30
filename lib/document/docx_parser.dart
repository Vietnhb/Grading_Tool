import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../core/app_exception.dart';
import '../grading/grading_models.dart';

class DocxTextReader {
  const DocxTextReader();

  Future<GradingGuide> read(File file) async {
    try {
      final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
      final documentFile = archive.findFile('word/document.xml');
      if (documentFile == null) {
        throw const AppException(
          'DOCX file does not contain word/document.xml.',
        );
      }
      return DocxDocumentParser().parse(
        XmlDocument.parse(utf8.decode(documentFile.content as List<int>)),
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException(
        'Could not read DOCX file: ${file.path}. Details: $error',
      );
    }
  }
}

class DocxDocumentParser {
  final _blocks = <DocumentBlock>[];
  final _sections = <SectionBlock>[];

  GradingGuide parse(XmlDocument document) {
    for (final child in document.body.children.whereType<XmlElement>()) {
      switch (child.name.local) {
        case 'p':
          _paragraph(child);
        case 'tbl':
          final table = _table(child);
          if (table.rows.isNotEmpty) _add(table);
      }
    }
    final maxScores = _extractMaxScores(_blocks);
    return GradingGuide(_blocks, maxScores: maxScores);
  }

  Map<int, int> _extractMaxScores(List<DocumentBlock> blocks) {
    final scores = <int, int>{};
    for (final block in blocks) {
      if (block is RubricTableBlock) {
        for (final row in block.rows) {
          if (row.isHeader || row.cells.length < 2) continue;
          final cell0 = row.cells[0].toLowerCase();
          final cell1 = row.cells[1].toLowerCase();
          
          final match = RegExp(r'(?:yêu cầu|question)\s*(\d+)').firstMatch(cell0);
          if (match != null) {
            final qIdx = int.parse(match.group(1)!) - 1;
            final scoreMatch = RegExp(r'(\d+)').firstMatch(cell1);
            if (scoreMatch != null) {
              scores[qIdx] = int.parse(scoreMatch.group(1)!);
            }
          }
        }
      }
      if (block is SectionBlock) {
        scores.addAll(_extractMaxScores(block.children));
      }
    }
    return scores;
  }

  void _paragraph(XmlElement paragraph) {
    final text = paragraph.textContent.trim();
    if (text.isEmpty) return;

    final properties = paragraph.child('pPr');
    final styleId = properties?.child('pStyle')?.attr('val');
    final headingLevel = _headingLevel(styleId);
    if (headingLevel != null) {
      _section(text, headingLevel, styleId);
      return;
    }

    final numbering = properties?.child('numPr');
    if (numbering == null) {
      _add(ParagraphBlock(text: text, styleId: styleId));
      return;
    }

    final item = BulletListItemBlock(
      text: text,
      level: int.tryParse(numbering.child('ilvl')?.attr('val') ?? '') ?? 0,
      numberingId: numbering.child('numId')?.attr('val'),
    );
    final target = _target;
    final previous = target.isEmpty ? null : target.last;
    if (previous is BulletListBlock &&
        previous.numberingId == item.numberingId) {
      previous.items.add(item);
    } else {
      _add(BulletListBlock(items: [item], numberingId: item.numberingId));
    }
  }

  void _section(String text, int level, String? styleId) {
    while (_sections.isNotEmpty && _sections.last.heading.level >= level) {
      _sections.removeLast();
    }
    final section = SectionBlock(
      heading: HeadingBlock(text: text, level: level, styleId: styleId),
      children: [],
    );
    _add(section);
    _sections.add(section);
  }

  RubricTableBlock _table(XmlElement table) {
    final firstRowIsHeader =
        table.child('tblPr')?.child('tblLook')?.attr('firstRow') == '1';
    final rows = table.children
        .whereType<XmlElement>()
        .where((row) => row.name.local == 'tr')
        .map(_row)
        .where((row) => row.any((cell) => cell.isNotEmpty))
        .toList();

    return RubricTableBlock(
      rows: [
        for (var i = 0; i < rows.length; i += 1)
          RubricTableRowBlock(
            cells: rows[i],
            isHeader: firstRowIsHeader && i == 0,
          ),
      ],
    );
  }

  List<String> _row(XmlElement row) => row.children
      .whereType<XmlElement>()
      .where((cell) => cell.name.local == 'tc')
      .map((cell) => cell.textContent.compactSpaces())
      .toList();

  void _add(DocumentBlock block) => _target.add(block);

  List<DocumentBlock> get _target =>
      _sections.isEmpty ? _blocks : _sections.last.children;

  int? _headingLevel(String? styleId) {
    final style = styleId?.toLowerCase().replaceAll(' ', '');
    if (style == 'title') return 1;
    const prefix = 'heading';
    return style != null && style.startsWith(prefix)
        ? int.tryParse(style.substring(prefix.length))
        : null;
  }
}

extension on XmlDocument {
  XmlElement get body => descendants.whereType<XmlElement>().firstWhere(
    (element) => element.name.local == 'body',
  );
}

extension on XmlElement {
  XmlElement? child(String name) {
    for (final child in children.whereType<XmlElement>()) {
      if (child.name.local == name) return child;
    }
    return null;
  }

  String? attr(String name) {
    for (final attribute in attributes) {
      if (attribute.name.local == name) return attribute.value;
    }
    return null;
  }

  String get textContent => descendants
      .whereType<XmlElement>()
      .where((element) => element.name.local == 't')
      .map((element) => element.innerText)
      .join();
}

extension on String {
  String compactSpaces() {
    final buffer = StringBuffer();
    var spaced = false;
    for (final codePoint in runes) {
      final char = String.fromCharCode(codePoint);
      final space = char.trim().isEmpty;
      if (!space) buffer.write(char);
      if (space && !spaced) buffer.write(' ');
      spaced = space;
    }
    return buffer.toString().trim();
  }
}
