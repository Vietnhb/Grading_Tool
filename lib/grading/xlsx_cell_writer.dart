import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../core/app_exception.dart';

class XlsxCellWriter {
  XlsxCellWriter(List<int> bytes, String sheetName)
    : _bytes = bytes,
      _sheetXmlPath = _sheetPath(bytes, sheetName);

  List<int> _bytes;
  final String _sheetXmlPath;

  List<int> patch(List<XlsxCellWrite> writes) {
    // Patch truc tiep XML trong file XLSX. File nao la worksheet dang cham
    // thi sua cell, cac file khac copy nguyen.
    final sourceArchive = ZipDecoder().decodeBytes(_bytes);
    final targetArchive = Archive();

    for (final file in sourceArchive.files) {
      if (!file.isFile) {
        targetArchive.addFile(file);
        continue;
      }

      final content = file.name == _sheetXmlPath
          ? _patchedSheet(file, writes)
          : _copiedFile(file);
      targetArchive.addFile(ArchiveFile(file.name, content.length, content));
    }

    final encoded = ZipEncoder().encode(targetArchive);
    if (encoded == null) {
      throw const AppException('Could not save the Excel workbook.');
    }
    _bytes = encoded;
    return encoded;
  }

  List<int> _patchedSheet(ArchiveFile file, List<XlsxCellWrite> writes) {
    // Parse XML cua sheet va giao cho _WorksheetPatcher sua tung cell.
    final document = XmlDocument.parse(utf8.decode(file.content as List<int>));
    _WorksheetPatcher(document).patch(writes);
    return utf8.encode(document.toXmlString());
  }

  List<int> _copiedFile(ArchiveFile file) {
    if (file.name == 'xl/workbook.xml') {
      return _workbookWithRecalculation(file);
    }
    return file.content as List<int>;
  }

  List<int> _workbookWithRecalculation(ArchiveFile file) {
    // Bat Excel tinh lai cong thuc khi user mo workbook sau khi app da ghi diem.
    final document = XmlDocument.parse(utf8.decode(file.content as List<int>));
    final workbook = document.findAllElements('workbook').first;
    final calcPrElements = document.findAllElements('calcPr');
    final calcPr = calcPrElements.isEmpty
        ? XmlElement(XmlName('calcPr'))
        : calcPrElements.first;

    calcPr.setAttribute('calcMode', 'auto');
    calcPr.setAttribute('fullCalcOnLoad', '1');
    calcPr.setAttribute('forceFullCalc', '1');

    if (calcPrElements.isEmpty) {
      workbook.children.add(calcPr);
    }
    return utf8.encode(document.toXmlString());
  }

  static String _sheetPath(List<int> bytes, String sheetName) {
    // Tim duong dan XML cua sheet theo ten sheet trong workbook relationships.
    final archive = ZipDecoder().decodeBytes(bytes);
    final workbookFile = archive.findFile('xl/workbook.xml');
    final relationsFile = archive.findFile('xl/_rels/workbook.xml.rels');
    if (workbookFile == null || relationsFile == null) {
      throw const AppException('Could not read workbook sheet relationships.');
    }

    final workbook = XmlDocument.parse(
      utf8.decode(workbookFile.content as List<int>),
    );
    final relations = XmlDocument.parse(
      utf8.decode(relationsFile.content as List<int>),
    );
    String? relationshipId;
    for (final sheet in workbook.findAllElements('sheet')) {
      if (sheet.getAttribute('name') == sheetName) {
        relationshipId = sheet.getAttribute('r:id');
        break;
      }
    }

    if (relationshipId == null) {
      throw const AppException('Could not locate the selected worksheet.');
    }

    String? target;
    for (final relationship in relations.findAllElements('Relationship')) {
      if (relationship.getAttribute('Id') == relationshipId) {
        target = relationship.getAttribute('Target');
        break;
      }
    }

    if (target == null || target.isEmpty) {
      throw const AppException('Could not locate the selected worksheet file.');
    }
    return _targetPath(target);
  }

  static String _targetPath(String target) {
    final normalized = target.replaceAll('\\', '/');
    if (normalized.startsWith('/')) {
      return normalized.substring(1);
    }
    if (normalized.startsWith('xl/')) {
      return normalized;
    }
    return 'xl/$normalized';
  }
}

class XlsxCellWrite {
  const XlsxCellWrite.text(this.rowIndex, this.columnIndex, String value)
    : textValue = value,
      numberValue = null;

  const XlsxCellWrite.number(this.rowIndex, this.columnIndex, int? value)
    : textValue = null,
      numberValue = value;

  final int rowIndex;
  final int columnIndex;
  final String? textValue;
  final int? numberValue;

  bool get isEmpty {
    return textValue == '' || (textValue == null && numberValue == null);
  }
}

class _WorksheetPatcher {
  _WorksheetPatcher(this.document);

  final XmlDocument document;

  void patch(List<XlsxCellWrite> writes) {
    // Sap xep writes theo row/column roi ghi lan luot vao sheetData.
    final sheetDataElements = document.findAllElements('sheetData');
    if (sheetDataElements.isEmpty) {
      throw const AppException('Could not find worksheet data.');
    }

    final sheetData = sheetDataElements.first;
    final sortedWrites = writes.toList()
      ..sort((a, b) {
        final rowCompare = a.rowIndex.compareTo(b.rowIndex);
        return rowCompare != 0
            ? rowCompare
            : a.columnIndex.compareTo(b.columnIndex);
      });

    for (final write in sortedWrites) {
      final row = _row(sheetData, write.rowIndex);
      final cell = _cell(row, write);
      _setValue(cell, write);
    }
  }

  XmlElement _row(XmlElement sheetData, int rowIndex) {
    final rowNumber = rowIndex + 1;
    for (final row in sheetData.findElements('row')) {
      final currentRowNumber = int.tryParse(row.getAttribute('r') ?? '');
      if (currentRowNumber == rowNumber) {
        return row;
      }
    }
    throw AppException('Excel row $rowNumber was not found.');
  }

  XmlElement _cell(XmlElement row, XlsxCellWrite write) {
    // Tim cell co san. Neu cell chua ton tai thi tao cell moi dung vi tri cot.
    final reference = _reference(write.columnIndex, write.rowIndex);
    for (final cell in row.findElements('c').toList()) {
      final columnIndex = _columnIndex(cell.getAttribute('r'));
      if (cell.getAttribute('r') == reference) {
        return cell;
      }
      if (columnIndex != null && columnIndex > write.columnIndex) {
        final newCell = _newCell(write);
        row.children.insert(row.children.indexOf(cell), newCell);
        return newCell;
      }
    }

    final newCell = _newCell(write);
    row.children.add(newCell);
    return newCell;
  }

  XmlElement _newCell(XlsxCellWrite write) {
    final attributes = [
      XmlAttribute(XmlName('r'), _reference(write.columnIndex, write.rowIndex)),
    ];
    return XmlElement(XmlName('c'), attributes);
  }

  void _setValue(XmlElement cell, XlsxCellWrite write) {
    // Ghi gia tri vao XML cell: text dung inlineStr, number dung <v>.
    // Neu value rong thi xoa noi dung cell.
    cell.children.clear();
    cell.attributes.removeWhere((attribute) => attribute.name.local == 't');

    if (write.isEmpty) {
      return;
    }
    if (write.textValue != null) {
      cell.attributes.add(XmlAttribute(XmlName('t'), 'inlineStr'));
      cell.children.add(
        XmlElement(XmlName('is'), [], [
          XmlElement(XmlName('t'), [], [XmlText(write.textValue!)]),
        ]),
      );
      return;
    }
    cell.children.add(
      XmlElement(XmlName('v'), [], [XmlText(write.numberValue.toString())]),
    );
  }

  String _reference(int columnIndex, int rowIndex) {
    var column = '';
    var index = columnIndex;
    while (index >= 0) {
      column = String.fromCharCode(65 + index % 26) + column;
      index = index ~/ 26 - 1;
    }
    return '$column${rowIndex + 1}';
  }

  int? _columnIndex(String? reference) {
    if (reference == null || reference.isEmpty) {
      return null;
    }

    var columnIndex = 0;
    var hasLetters = false;
    for (final codeUnit in reference.codeUnits) {
      final upper = codeUnit >= 97 && codeUnit <= 122
          ? codeUnit - 32
          : codeUnit;
      if (upper < 65 || upper > 90) {
        break;
      }
      hasLetters = true;
      columnIndex = columnIndex * 26 + upper - 64;
    }
    return hasLetters ? columnIndex - 1 : null;
  }
}
