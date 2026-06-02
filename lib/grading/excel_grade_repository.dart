import 'dart:io';

import 'package:excel/excel.dart';

import '../core/app_exception.dart';
import 'grading_models.dart';
import 'xlsx_cell_writer.dart';

class ExcelGradeRepository {
  late File _file;
  late Excel _workbook;
  late SheetLayout _layout;
  late XlsxCellWriter _cellWriter;
  Map<String, int> _aliasRows = {};
  Set<String> _markers = {};

  List<String> get markerOptions {
    final markers =
        _markers.where((marker) => marker.trim().isNotEmpty).toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return markers;
  }

  Future<Map<String, GradingEntry>> open(
    File file,
    List<String> aliases,
  ) async {
    // Mo file Excel:
    // 1) decode workbook, 2) tim layout cot, 3) map alias -> row,
    // 4) doc diem/comment cho tung alias.
    _file = file;
    final bytes = await file.readAsBytes();
    _workbook = _decodeWorkbook(bytes);
    _layout = _detectLayout();
    _cellWriter = XlsxCellWriter(bytes, _layout.sheetName);
    final sheet = _workbook[_layout.sheetName];
    _aliasRows = _buildAliasRows(sheet);
    _markers = _readMarkers(sheet);

    final entries = <String, GradingEntry>{};
    for (final alias in aliases) {
      entries[alias] = _readEntry(alias);
    }
    return entries;
  }

  Future<void> saveEntry(GradingEntry entry) async {
    // Luu 1 GradingEntry vao dung row Excel.
    // Flow tiep theo: _writesFor -> XlsxCellWriter.patch -> _replaceWorkbookSafely.
    final sheet = _workbook[_layout.sheetName];
    final rowIndex = _rowForAlias(entry.alias);
    final writes = _writesFor(rowIndex, entry);
    _cacheEntry(sheet, rowIndex, entry);
    final workbookBytes = _cellWriter.patch(writes);
    await _replaceWorkbookSafely(workbookBytes);
  }

  List<XlsxCellWrite> _writesFor(int rowIndex, GradingEntry entry) {
    // Bien GradingEntry thanh danh sach cell can ghi: Alias, Marker,
    // tung Question score, Total neu workbook co cot nay, va Comment.
    final writes = <XlsxCellWrite>[
      XlsxCellWrite.text(rowIndex, _layout.aliasColumn, entry.alias),
    ];

    writes.add(
      XlsxCellWrite.text(rowIndex, _layout.markerColumn, entry.marker),
    );

    for (var index = 0; index < _layout.requestColumns.length; index += 1) {
      writes.add(
        XlsxCellWrite.number(
          rowIndex,
          _layout.requestColumns[index],
          entry.requestScores[index],
        ),
      );
    }
    final totalColumn = _layout.totalColumn;
    if (totalColumn != null) {
      writes.add(XlsxCellWrite.number(rowIndex, totalColumn, entry.total));
    }
    writes.add(
      XlsxCellWrite.text(rowIndex, _layout.commentColumn, entry.comment),
    );
    return writes;
  }

  void _cacheEntry(Sheet sheet, int rowIndex, GradingEntry entry) {
    // Cap nhat workbook trong memory de lan doc/luu tiep theo thay du lieu moi.
    _cacheText(sheet, rowIndex, _layout.aliasColumn, entry.alias);

    _cacheText(sheet, rowIndex, _layout.markerColumn, entry.marker);
    if (entry.marker.trim().isNotEmpty) {
      _markers.add(entry.marker.trim());
    }

    for (var index = 0; index < _layout.requestColumns.length; index += 1) {
      _cacheNumber(
        sheet,
        rowIndex,
        _layout.requestColumns[index],
        entry.requestScores[index],
      );
    }
    final totalColumn = _layout.totalColumn;
    if (totalColumn != null) {
      _cacheNumber(sheet, rowIndex, totalColumn, entry.total);
    }
    _cacheText(sheet, rowIndex, _layout.commentColumn, entry.comment);
  }

  GradingEntry _readEntry(String alias) {
    // Doc 1 dong Excel theo alias. Neu alias chua co trong Excel thi tao entry rong.
    final sheet = _workbook[_layout.sheetName];
    final rowIndex = _aliasRows[alias];
    if (rowIndex == null) {
      return GradingEntry.empty(
        alias,
        questionCount: _layout.requestColumns.length,
      );
    }
    return GradingEntry(
      alias: alias,
      marker: _readText(sheet, rowIndex, _layout.markerColumn),
      requestScores: _layout.requestColumns
          .map((column) => _readNumber(sheet, rowIndex, column))
          .toList(),
      comment: _readText(sheet, rowIndex, _layout.commentColumn),
    );
  }

  SheetLayout _detectLayout() {
    // Tu dong tim sheet va cac cot can thiet trong 20 dong dau:
    // Alias, Marker, Question 1..n, Comment.
    for (final sheetName in _workbook.tables.keys) {
      final sheet = _workbook[sheetName];
      final rows = sheet.rows;
      final maxRows = rows.length < 20 ? rows.length : 20;
      for (var rowIndex = 0; rowIndex < maxRows; rowIndex += 1) {
        final headers = _headerValues(rows, rowIndex);
        final aliasColumn = _findColumn(headers, const ['alias']);
        if (aliasColumn == null) {
          continue;
        }
        final requestColumns = _questionColumns(headers);
        if (requestColumns.isEmpty) {
          continue;
        }
        final markerColumn = _findColumn(headers, const ['marker']);
        if (markerColumn == null) {
          continue;
        }
        final commentColumn = _findColumn(headers, const ['comment']);
        if (commentColumn == null) {
          continue;
        }
        final totalColumn = _findColumn(headers, const [
          'total',
          'total score',
          'total mark',
          'score',
          'mark',
        ]);
        return SheetLayout(
          sheetName: sheetName,
          headerRow: rowIndex,
          aliasColumn: aliasColumn,
          markerColumn: markerColumn,
          requestColumns: requestColumns,
          totalColumn: totalColumn,
          commentColumn: commentColumn,
        );
      }
    }
    throw const AppException(
      'Could not detect Excel columns. Expected Alias, Marker, Question, and Comment columns.',
    );
  }

  List<int> _questionColumns(Map<int, String> headers) {
    final columnsByQuestion = <int, int>{};

    for (final entry in headers.entries) {
      final questionNumber = _questionNumber(entry.value);
      if (questionNumber == null) {
        continue;
      }
      columnsByQuestion[questionNumber] = entry.key;
    }

    final questionNumbers = columnsByQuestion.keys.toList()..sort();
    for (var index = 0; index < questionNumbers.length; index += 1) {
      if (questionNumbers[index] != index + 1) {
        return [];
      }
    }
    return [
      for (final questionNumber in questionNumbers)
        columnsByQuestion[questionNumber]!,
    ];
  }

  int? _questionNumber(String header) {
    const prefix = 'question';
    if (!header.startsWith(prefix) || header.length == prefix.length) {
      return null;
    }

    var index = prefix.length;
    var hasSpace = false;
    while (index < header.length && header.codeUnitAt(index) == 32) {
      hasSpace = true;
      index += 1;
    }
    if (!hasSpace || index == header.length) {
      return null;
    }

    final number = header.substring(index);
    return int.tryParse(number);
  }

  Map<int, String> _headerValues(List<List<Data?>> rows, int rowIndex) {
    final headers = <int, String>{};
    if (rowIndex > 0) {
      _addHeaderValues(headers, rows[rowIndex - 1]);
    }
    _addHeaderValues(headers, rows[rowIndex]);
    return headers;
  }

  void _addHeaderValues(Map<int, String> headers, List<Data?> row) {
    for (var columnIndex = 0; columnIndex < row.length; columnIndex += 1) {
      final value = row[columnIndex]?.value?.toString().trim().toLowerCase();
      if (value != null && value.isNotEmpty && !_isNumeric(value)) {
        headers[columnIndex] = '${headers[columnIndex] ?? ''} $value'.trim();
      }
    }
  }

  bool _isNumeric(String value) {
    return int.tryParse(value) != null || double.tryParse(value) != null;
  }

  int? _findColumn(Map<int, String> headers, List<String> expectedHeaders) {
    for (final entry in headers.entries) {
      for (final expectedHeader in expectedHeaders) {
        if (entry.value == expectedHeader) {
          return entry.key;
        }
      }
    }
    return null;
  }

  Map<String, int> _buildAliasRows(Sheet sheet) {
    // Tao map alias -> rowIndex de luu diem dung dong sinh vien.
    final rows = <String, int>{};
    for (
      var rowIndex = _layout.headerRow + 1;
      rowIndex < sheet.rows.length;
      rowIndex += 1
    ) {
      final alias = _readText(sheet, rowIndex, _layout.aliasColumn);
      if (alias.isNotEmpty) {
        rows[alias] = rowIndex;
      }
    }
    return rows;
  }

  Set<String> _readMarkers(Sheet sheet) {
    // Doc danh sach marker da co trong Excel de hien dropdown filter.
    final markers = <String>{};
    for (
      var rowIndex = _layout.headerRow + 1;
      rowIndex < sheet.rows.length;
      rowIndex += 1
    ) {
      final marker = _readText(sheet, rowIndex, _layout.markerColumn);
      if (marker.isNotEmpty) {
        markers.add(marker);
      }
    }
    return markers;
  }

  int _rowForAlias(String alias) {
    final existingRow = _aliasRows[alias];
    if (existingRow != null) {
      return existingRow;
    }
    throw AppException('Alias $alias was not found in the Excel workbook.');
  }

  String _readText(Sheet sheet, int rowIndex, int columnIndex) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex),
    );
    return cell.value?.toString().trim() ?? '';
  }

  int? _readNumber(Sheet sheet, int rowIndex, int columnIndex) {
    final value = _readText(sheet, rowIndex, columnIndex);
    if (value.isEmpty) {
      return null;
    }
    return int.tryParse(value) ?? double.tryParse(value)?.round();
  }

  void _cacheText(Sheet sheet, int rowIndex, int columnIndex, String value) {
    final cellValue = TextCellValue(value);
    final cellIndex = CellIndex.indexByColumnRow(
      columnIndex: columnIndex,
      rowIndex: rowIndex,
    );
    sheet.updateCell(cellIndex, cellValue);
  }

  void _cacheNumber(Sheet sheet, int rowIndex, int columnIndex, int? value) {
    final cellValue = value == null ? null : IntCellValue(value);
    final cellIndex = CellIndex.indexByColumnRow(
      columnIndex: columnIndex,
      rowIndex: rowIndex,
    );
    sheet.updateCell(cellIndex, cellValue);
  }

  Excel _decodeWorkbook(List<int> bytes) {
    try {
      return Excel.decodeBytes(bytes);
    } catch (error) {
      throw AppException(
        'Could not open the XLSX/XLSM mark input file. The workbook may be corrupted or unsupported. Details: $error',
      );
    }
  }

  Future<void> _replaceWorkbookSafely(List<int> bytes) async {
    // Ghi file an toan: ghi .tmp truoc, rename file cu sang .bak,
    // roi thay bang file moi. Neu loi thi co gang restore backup.
    final tempFile = File('${_file.path}.tmp');
    final backupFile = File('${_file.path}.bak');
    try {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
      await tempFile.writeAsBytes(bytes, flush: true);
      if (await _file.exists()) {
        await _file.rename(backupFile.path);
      }
      try {
        await tempFile.rename(_file.path);
      } on FileSystemException {
        if (await backupFile.exists() && !await _file.exists()) {
          await backupFile.rename(_file.path);
        }
        rethrow;
      }
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
    } on FileSystemException catch (error) {
      if (await tempFile.exists()) {
        await _deleteIfPossible(tempFile);
      }
      if (await backupFile.exists() && !await _file.exists()) {
        await _restoreIfPossible(backupFile);
      }
      throw AppException(
        'Could not save the Excel file. Close the workbook in Excel and try again. Details: $error',
      );
    }
  }

  Future<void> _deleteIfPossible(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      return;
    }
  }

  Future<void> _restoreIfPossible(File backupFile) async {
    try {
      await backupFile.rename(_file.path);
    } on FileSystemException {
      return;
    }
  }
}

class SheetLayout {
  const SheetLayout({
    required this.sheetName,
    required this.headerRow,
    required this.aliasColumn,
    required this.markerColumn,
    required this.requestColumns,
    required this.totalColumn,
    required this.commentColumn,
  });

  final String sheetName;
  final int headerRow;
  final int aliasColumn;
  final int markerColumn;
  final List<int> requestColumns;
  final int? totalColumn;
  final int commentColumn;
}
