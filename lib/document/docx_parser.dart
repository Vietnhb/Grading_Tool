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
    return GradingGuide(
      _blocks,
      maxScores: _extractMaxScores(_blocks),
      questions: _extractQuestions(_blocks),
    );
  }

  Map<int, int> _extractMaxScores(List<DocumentBlock> blocks) {
    final scores = <int, int>{};
    for (final block in blocks) {
      switch (block) {
        case SectionBlock(:final children):
          scores.addAll(_extractMaxScores(children));
        case RubricTableBlock(:final rows):
          for (final row in rows) {
            if (row.isHeader || row.cells.length < 2) continue;
            final match = _questionHeading(row.cells.first);
            if (match == null) continue;
            final scoreMatch = RegExp(r'\d+').firstMatch(row.cells[1]);
            if (scoreMatch == null) continue;
            scores[int.parse(match.group(1)!) - 1] = int.parse(
              scoreMatch.group(0)!,
            );
          }
        case ParagraphBlock():
          break;
        case BulletListBlock():
          break;
      }
    }
    return scores;
  }

  List<ExamQuestion> _extractQuestions(List<DocumentBlock> blocks) {
    final lines = <String>[];
    for (final block in blocks) {
      _flattenText(block, lines);
    }

    final questions = <ExamQuestion>[];
    _QuestionDraft? draft;
    for (final line in lines) {
      final match = _questionHeading(line);
      if (match != null) {
        if (draft != null) {
          questions.add(draft.toQuestion());
        }
        draft = _QuestionDraft(
          number: int.parse(match.group(1)!),
          title: line,
        );
        continue;
      }
      draft?.lines.add(line);
    }
    if (draft != null) {
      questions.add(draft.toQuestion());
    }
    return questions;
  }

  RegExpMatch? _questionHeading(String text) {
    return RegExp(
      r'^(?:yêu cầu|request|requirement|question)\s*(\d+)\b',
      caseSensitive: false,
    ).firstMatch(text.trim());
  }

  void _flattenText(DocumentBlock block, List<String> lines) {
    switch (block) {
      case SectionBlock(:final heading, :final children):
        _addLine(heading.text, lines);
        for (final child in children) {
          _flattenText(child, lines);
        }
      case ParagraphBlock(:final text):
        _addLine(text, lines);
      case BulletListBlock(:final items):
        for (final item in items) {
          _addLine(item.text, lines);
        }
      case RubricTableBlock(:final rows):
        for (final row in rows) {
          _addLine(row.cells.join(' | '), lines);
        }
    }
  }

  void _addLine(String text, List<String> lines) {
    final line = text.compactSpaces();
    if (line.isNotEmpty) {
      lines.add(line);
    }
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

class _QuestionDraft {
  _QuestionDraft({required this.number, required this.title});

  final int number;
  final String title;
  final List<String> lines = [];

  ExamQuestion toQuestion() {
    return ExamQuestion(
      number: number,
      title: title,
      content: lines.join('\n').trim(),
    );
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
