import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:xml/xml.dart';
import 'package:path/path.dart' as p;

import 'models.dart';

/// Reads a .docx file and returns the concatenated paragraph texts
Future<List<String>> extractParagraphsFromDocx(File docx) async {
  final bytes = await docx.readAsBytes();
  final archive = ZipDecoder().decodeBytes(bytes);
  final documentFile = archive.files.firstWhere(
    (f) => f.name.toLowerCase() == 'word/document.xml',
    orElse: () => throw Exception('word/document.xml not found in docx'),
  );

  final xmlText = utf8.decode(documentFile.content as List<int>);
  final doc = XmlDocument.parse(xmlText);

  // Gather paragraphs
  final paragraphs = <String>[];
  for (final pNode in doc.findAllElements('w:p')) {
    final buffer = StringBuffer();
    for (final node in pNode.findAllElements('w:t')) {
      buffer.write(node.text);
    }
    final txt = buffer.toString().trim();
    if (txt.isNotEmpty) paragraphs.add(txt);
  }
  return paragraphs;
}

/// Splits paragraphs into DocumentBlocks keyed by Request headings.
List<MapEntry<String, List<String>>> splitIntoRequests(
    List<String> paragraphs) {
  final blocks = <MapEntry<String, List<String>>>[];
  String? currentId;
  List<String>? currentLines;

  final requestHeading = RegExp(
      r'^(Request\s*\d+|Request\s*\d+:|Request:\s*\d+|Request)\b',
      caseSensitive: false);
  final numberedHeading = RegExp(r'^\d+\.)');

  for (final p in paragraphs) {
    if (requestHeading.hasMatch(p) || p.toLowerCase().startsWith('request')) {
      // start new block
      if (currentId != null && currentLines != null) {
        blocks.add(MapEntry(currentId, currentLines));
      }
      // derive id from heading
      final idMatch =
          RegExp(r'Request\s*(\d+)', caseSensitive: false).firstMatch(p);
      final id = idMatch != null
          ? 'Request${idMatch.group(1)}'
          : 'Request${blocks.length + 1}';
      currentId = id;
      currentLines = [p];
    } else if (currentLines != null) {
      currentLines.add(p);
    } else {
      // paragraphs before first request are ignored or could be attached to general doc
    }
  }
  if (currentId != null && currentLines != null)
    blocks.add(MapEntry(currentId, currentLines));
  return blocks;
}

num? _extractNumber(String s) {
  // look for patterns like '20', '(20)', '20 pts', '20 điểm', 'Max 20', 'total 20'
  final patterns = [
    RegExp(r'\b(\d{1,3}(?:[\.,]\d+)?)\s*(pts?|points?|điểm|pt)\b',
        caseSensitive: false),
    RegExp(r'\((\d{1,3}(?:[\.,]\d+)?)\)'),
    RegExp(r'\b(total|max)[:\s]*?(\d{1,3}(?:[\.,]\d+)?)\b',
        caseSensitive: false),
    RegExp(r'\b(\d{1,3})(?:\s*[-–]\s*\d{1,3})?\b'),
  ];

  for (final re in patterns) {
    final m = re.firstMatch(s);
    if (m != null) {
      for (var i = 1; i <= m.groupCount; i++) {
        final g = m.group(i);
        if (g == null) continue;
        final val = num.tryParse(g.replaceAll(',', '.'));
        if (val != null) return val;
      }
    }
  }
  return null;
}

/// Heuristic parse a block of lines into a RubricRequest
RubricRequest parseRequestBlock(String id, List<String> lines) {
  final title = lines.isNotEmpty ? lines.first : id;
  num? total;
  final items = <String, RubricItem>{};

  // scan for total in entire block
  for (final l in lines) {
    final t = _extractNumber(l);
    if (t != null &&
        (l.toLowerCase().contains('total') ||
            l.toLowerCase().contains('total points') ||
            l.toLowerCase().contains('total:') ||
            l.toLowerCase().contains('tong'))) {
      total = t;
      break;
    }
  }

  // scan for numbered items like '1. Project Name: ...' or '1) Name – description (2)'
  final itemRe = RegExp(r'^(\d+(?:\.\d+)*)[\)\.:\s-]*\s*(.+)$');
  int autoIndex = 1;
  for (final l in lines.skip(1)) {
    final m = itemRe.firstMatch(l);
    if (m != null) {
      final code = m.group(1)!.trim();
      final rest = m.group(2)!.trim();
      final score = _extractNumber(rest);
      items[code] = RubricItem(
          code: code,
          name: rest.replaceAll(RegExp(r'\s*\([^\)]*\)\$'), '').trim(),
          maxScore: score);
    } else {
      // fallback: lines starting with a dash or bullet
      final dashRe = RegExp(r'^[\-\*]\s*(.+)$');
      final md = dashRe.firstMatch(l);
      if (md != null) {
        final code = '${autoIndex++}';
        final text = md.group(1)!.trim();
        final score = _extractNumber(text);
        items[code] = RubricItem(
            code: code,
            name: text.replaceAll(RegExp(r'\s*\([^\)]*\)\$'), '').trim(),
            maxScore: score);
      }
    }
  }

  return RubricRequest(id: id, title: title, total: total, items: items);
}

/// Full pipeline: docx -> rubric JSON
Future<Rubric> parseDocxRubric(File docx) async {
  final paragraphs = await extractParagraphsFromDocx(docx);
  final blocks = splitIntoRequests(paragraphs);
  final rubric = Rubric();
  for (final entry in blocks) {
    final req = parseRequestBlock(entry.key, entry.value);
    rubric.requests[entry.key] = req;
  }
  return rubric;
}

/// Generate a simple LLM prompt from a rubric and a student answer text
String generatePromptFromRubric(Rubric rubric, String studentAnswer,
    {String instructions =
        'Please grade the student answer according to the rubric. Return JSON with scores per item and comments.'}) {
  final buffer = StringBuffer();
  buffer.writeln(instructions);
  buffer.writeln();
  buffer.writeln('Rubric:');
  buffer.writeln(rubric.toPrettyJson());
  buffer.writeln();
  buffer.writeln('Student Answer:');
  buffer.writeln(studentAnswer);
  buffer.writeln();
  buffer.writeln(
      'Return format: JSON mapping request->item_code->score and optional comments.');
  return buffer.toString();
}

/// Save rubric JSON to file
Future<void> saveRubricJson(Rubric rubric, File out) async {
  await out.writeAsString(rubric.toPrettyJson());
}
