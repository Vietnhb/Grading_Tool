import 'dart:io';

import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'models.dart';
import 'rubric_parser.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PMG201 Grading Tool',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _dragging = false;
  Directory? _projectDir;
  List<File> _studentSolutions = [];
  File? _selectedGradingGuide;
  Rubric? _rubric;
  String? _selectedStudentFile;
  String? _studentPreview;
  String? _statusMessage;

  Future<void> _pickProjectFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      await _scanProjectFolder(Directory(result));
    }
  }

  Future<void> _scanProjectFolder(Directory dir) async {
    final studSolDir = Directory(p.join(dir.path, 'Student_Solutions'));
    List<File> students = [];

    if (await studSolDir.exists()) {
      await for (final entity in studSolDir.list(followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.txt')) {
          students.add(entity);
        }
      }
    }
    students.sort((a, b) => a.path.compareTo(b.path));

    setState(() {
      _projectDir = dir;
      _studentSolutions = students;
      _selectedGradingGuide = null;
      _rubric = null;
      _selectedStudentFile = null;
      _studentPreview = null;
      _statusMessage = 'Scanned: ${students.length} student solutions found.';
    });
  }

  Future<void> _selectGradingGuide() async {
    if (_projectDir == null) {
      setState(() => _statusMessage = 'Please select a project folder first.');
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      initialDirectory: _projectDir!.path,
      type: FileType.custom,
      allowedExtensions: ['docx'],
    );
    if (result != null && result.files.isNotEmpty) {
      final filePath = result.files.first.path;
      if (filePath != null) {
        final file = File(filePath);
        try {
          final rubric = await parseDocxRubric(file);
          setState(() {
            _selectedGradingGuide = file;
            _rubric = rubric;
            _statusMessage = 'Loaded rubric from ${p.basename(filePath)}';
          });
        } catch (e) {
          setState(() => _statusMessage = 'Error parsing rubric: $e');
        }
      }
    }
  }

  Future<void> _loadStudentSolution(String filePath) async {
    try {
      final content = await File(filePath).readAsString();
      setState(() {
        _selectedStudentFile = filePath;
        _studentPreview = content;
      });
    } catch (e) {
      setState(() => _studentPreview = 'Error loading: $e');
    }
  }

  Future<void> _batchGradeAndSave() async {
    if (_projectDir == null) {
      setState(() => _statusMessage = 'No project folder selected.');
      return;
    }
    if (_rubric == null) {
      setState(() => _statusMessage = 'No rubric loaded.');
      return;
    }

    try {
      final markInputPath =
          p.join(_projectDir!.path, 'PMG201c_SP26_2ndFE_PE_Mark_Input');
      final markInputDir = Directory(markInputPath);
      if (!await markInputDir.exists()) {
        await markInputDir.create(recursive: true);
      }

      final resultFile = File(p.join(markInputPath, 'grading_results.json'));
      final results = <String, dynamic>{};

      for (final sol in _studentSolutions) {
        final content = await sol.readAsString();
        final prompt = generatePromptFromRubric(_rubric!, content,
            instructions:
                'Grade the student answer. Return JSON with scores per item.');
        results[p.basenameWithoutExtension(sol.path)] = {
          'file': p.basename(sol.path),
          'prompt_preview':
              prompt.substring(0, (prompt.length > 200 ? 200 : prompt.length)),
        };
      }

      await resultFile.writeAsString(
        '${_rubric!.toPrettyJson()}\n\n// Grading prompts generated:\n${results.toString()}\n',
      );
      setState(() => _statusMessage = 'Batch grading saved to $markInputPath');
    } catch (e) {
      setState(() => _statusMessage = 'Error batch grading: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PMG201 Grading Tool')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickProjectFolder,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Select Project Folder'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _projectDir != null
                        ? _projectDir!.path
                        : 'No folder selected',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  _statusMessage!,
                  style: const TextStyle(fontSize: 12, color: Colors.green),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _selectGradingGuide,
                  icon: const Icon(Icons.description),
                  label: const Text('Select Grading Guide (.docx)'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedGradingGuide != null
                        ? p.basename(_selectedGradingGuide!.path)
                        : 'No rubric loaded',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _batchGradeAndSave,
              icon: const Icon(Icons.save),
              label: const Text('Batch Grade & Save'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Student Solutions (${_studentSolutions.length})',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _studentSolutions.length,
                            itemBuilder: (context, i) {
                              final file = _studentSolutions[i];
                              final basename =
                                  p.basenameWithoutExtension(file.path);
                              final isSelected =
                                  _selectedStudentFile == file.path;
                              return ListTile(
                                selected: isSelected,
                                title: Text(basename),
                                onTap: () => _loadStudentSolution(file.path),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Student Answer Preview',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                                _studentPreview ?? 'Select a student solution'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Rubric Preview',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(_rubric != null
                                ? _rubric!.toPrettyJson()
                                : 'Load a grading guide'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
