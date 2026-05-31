import 'package:flutter/material.dart';

class TopStatusBar extends StatelessWidget {
  const TopStatusBar({
    required this.gradedCount,
    required this.totalStudents,
    required this.markerOptions,
    required this.selectedMarker,
    required this.packagePath,
    required this.aiReady,
    required this.aiReadyLabel,
    required this.aiProviderStatus,
    required this.onMarkerChanged,
    required this.onAiSettings,
    required this.onOpenPackage,
    required this.onPrevious,
    required this.onNext,
    super.key,
  });

  final int gradedCount;
  final int totalStudents;
  final List<String> markerOptions;
  final String selectedMarker;
  final String packagePath;
  final bool aiReady;
  final String aiReadyLabel;
  final String aiProviderStatus;
  final ValueChanged<String> onMarkerChanged;
  final VoidCallback onAiSettings;
  final Future<void> Function() onOpenPackage;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE0E5E5))),
      ),
      child: Row(
        children: [
          Text(
            '$gradedCount / $totalStudents graded',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<String>(
              initialValue: selectedMarker,
              decoration: const InputDecoration(labelText: 'Marker'),
              items: [
                const DropdownMenuItem(value: '', child: Text('All markers')),
                ...markerOptions.map(
                  (marker) => DropdownMenuItem(
                    value: marker,
                    child: Text(marker, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (value) => onMarkerChanged(value ?? ''),
            ),
          ),
          const Spacer(),
          Expanded(
            flex: 2,
            child: Tooltip(
              message: packagePath,
              child: Text(packagePath, overflow: TextOverflow.ellipsis),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: aiProviderStatus,
            child: TextButton.icon(
              onPressed: onAiSettings,
              icon: Icon(aiReady ? Icons.check_circle : Icons.key, size: 18),
              label: Text(aiReadyLabel),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: packagePath.isEmpty ? null : () => onOpenPackage(),
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('Open'),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Previous',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Next',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
