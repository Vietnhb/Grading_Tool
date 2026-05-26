import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class DropPackagePanel extends StatefulWidget {
  const DropPackagePanel({
    required this.onPackageSelected,
    required this.isLoading,
    super.key,
  });

  final ValueChanged<String> onPackageSelected;
  final bool isLoading;

  @override
  State<DropPackagePanel> createState() => _DropPackagePanelState();
}

class _DropPackagePanelState extends State<DropPackagePanel> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        if (details.files.isNotEmpty) {
          widget.onPackageSelected(details.files.first.path);
        }
      },
      child: Center(
        child: Container(
          width: 560,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: _dragging ? const Color(0xFFE5F0EE) : Colors.white,
            border: Border.all(
              color: _dragging
                  ? const Color(0xFF2F5E5E)
                  : const Color(0xFFD6DCDC),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_open, size: 48, color: Color(0xFF2F5E5E)),
              const SizedBox(height: 18),
              Text(
                widget.isLoading
                    ? 'Scanning exam package...'
                    : 'Drop an exam package folder',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              const Text(
                'Expected: Mark Input XLSX, Student Solutions folder, grading guide , and question image.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: widget.isLoading ? null : _pickFolder,
                icon: const Icon(Icons.search),
                label: const Text('Select Folder'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFolder() async {
    final path = await FilePicker.getDirectoryPath();
    if (path != null) {
      widget.onPackageSelected(path);
    }
  }
}
