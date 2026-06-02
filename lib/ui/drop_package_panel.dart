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

class _DropPackagePanelState extends State<DropPackagePanel>
    with SingleTickerProviderStateMixin {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFA),
      body: DropTarget(
        onDragEntered: (_) => setState(() => _dragging = true),
        onDragExited: (_) => setState(() => _dragging = false),
        onDragDone: (details) {
          setState(() => _dragging = false);
          if (details.files.isNotEmpty) {
            widget.onPackageSelected(details.files.first.path);
          }
        },
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            width: 600,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 56),
            decoration: BoxDecoration(
              color: _dragging ? const Color(0xFFE8F3F1) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _dragging ? const Color(0xFF1E4C4C) : const Color(0xFFE0E5E5),
                width: _dragging ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _dragging
                      ? const Color(0xFF1E4C4C).withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: _dragging ? 24 : 12,
                  spreadRadius: _dragging ? 4 : 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: widget.isLoading ? _buildLoadingState() : _buildIdleState(),
          ),
        ),
      ),
    );
  }

  Widget _buildIdleState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedScale(
          scale: _dragging ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFF0F5F5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_upload_rounded,
              size: 56,
              color: Color(0xFF1E4C4C),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Drop exam package here',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1C1C),
              ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Please ensure your folder contains the following items:',
          style: TextStyle(
            fontSize: 15,
            color: Color(0xFF6B7272),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFCFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEFF2F2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildChecklistItem(Icons.table_chart_rounded, 'Mark Input XLSX file'),
              _buildChecklistItem(Icons.folder_shared_rounded, 'Student Solutions folder'),
              _buildChecklistItem(Icons.description_rounded, 'Grading guide (.docx)'),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Expanded(child: Divider(color: Color(0xFFE0E5E5))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR',
                style: TextStyle(
                  color: Color(0xFFA0A7A7),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const Expanded(child: Divider(color: Color(0xFFE0E5E5))),
          ],
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: _pickFolder,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1E4C4C),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          icon: const Icon(Icons.folder_open_rounded, size: 22),
          label: const Text(
            'Browse Files',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF2E7D7D)),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF4A5252),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E4C4C)),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Scanning exam package...',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1C1C),
                ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Extracting rubric and preparing AI constraints',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF6B7272),
            ),
          ),
        ],
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

