import 'package:flutter/material.dart';

class TopStatusBar extends StatelessWidget {
  const TopStatusBar({
    required this.currentIndex,
    required this.currentAlias,
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
    required this.onClosePackage,
    required this.onFirst,
    required this.onPrevious,
    required this.onNext,
    required this.onLast,
    required this.onAliasSubmitted,
    super.key,
  });

  final int currentIndex;
  final String currentAlias;
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
  final VoidCallback onClosePackage;
  final VoidCallback onFirst;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onLast;
  final ValueChanged<String> onAliasSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFE0E5E5))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            offset: const Offset(0, 2),
            blurRadius: 4,
          )
        ],
      ),
      child: Row(
        children: [
          _buildNavigationGroup(),
          const SizedBox(width: 16),
          Container(width: 1, height: 24, color: const Color(0xFFE0E5E5)),
          const SizedBox(width: 16),
          _buildProgressPill(),
          const SizedBox(width: 16),
          _buildMarkerDropdown(),
          const Spacer(),
          _buildPackageInfo(),
          const SizedBox(width: 16),
          _buildAiSettingsButton(),
          const SizedBox(width: 12),
          _buildIconButton(Icons.folder_open_rounded, 'Open Folder', onOpenPackage),
          const SizedBox(width: 4),
          _buildIconButton(Icons.swap_horiz_rounded, 'Change Folder', onClosePackage),
        ],
      ),
    );
  }

  Widget _buildNavigationGroup() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIconButton(Icons.first_page_rounded, 'First Student', onFirst),
        _buildIconButton(Icons.chevron_left_rounded, 'Previous Student', onPrevious),
        _AliasJumpField(
          currentAlias: currentAlias,
          onSubmitted: onAliasSubmitted,
        ),
        _AliasPositionText(
          currentPosition: totalStudents == 0 ? 0 : currentIndex + 1,
          totalStudents: totalStudents,
        ),
        _buildIconButton(Icons.chevron_right_rounded, 'Next Student', onNext),
        _buildIconButton(Icons.last_page_rounded, 'Last Student', onLast),
      ],
    );
  }

  Widget _buildProgressPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.analytics_outlined, size: 16, color: Color(0xFF4A5252)),
          const SizedBox(width: 6),
          Text(
            '$gradedCount graded',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A5252),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkerDropdown() {
    return SizedBox(
      height: 36,
      width: 180,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE0E5E5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            icon: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF6B7272)),
            ),
            padding: const EdgeInsets.only(left: 12),
            value: selectedMarker,
            style: const TextStyle(
              color: Color(0xFF1A1C1C),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
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
      ),
    );
  }

  Widget _buildPackageInfo() {
    if (packagePath.isEmpty) return const SizedBox.shrink();
    
    // Extract folder name on Windows or Mac
    final parts = packagePath.split(RegExp(r'[\\/]'));
    final folderName = parts.isNotEmpty ? parts.last : packagePath;

    return Expanded(
      flex: 2,
      child: Tooltip(
        message: packagePath,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Icon(Icons.topic_outlined, size: 16, color: Color(0xFF98A2A2)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                folderName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6B7272),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiSettingsButton() {
    return Tooltip(
      message: aiProviderStatus,
      child: TextButton.icon(
        onPressed: onAiSettings,
        style: TextButton.styleFrom(
          foregroundColor: aiReady ? const Color(0xFF2E7D7D) : const Color(0xFF6B7272),
          backgroundColor: aiReady ? const Color(0xFFE8F3F1) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(aiReady ? Icons.auto_awesome : Icons.key_rounded, size: 16),
        label: Text(aiReadyLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        splashRadius: 20,
        iconSize: 20,
        color: const Color(0xFF4A5252),
        icon: Icon(icon),
      ),
    );
  }
}

class _AliasPositionText extends StatelessWidget {
  const _AliasPositionText({
    required this.currentPosition,
    required this.totalStudents,
  });

  final int currentPosition;
  final int totalStudents;

  @override
  Widget build(BuildContext context) {
    if (totalStudents == 0) {
      return const SizedBox(width: 8);
    }
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 4),
      child: Text(
        '$currentPosition/$totalStudents',
        style: const TextStyle(
          color: Color(0xFF6B7272),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AliasJumpField extends StatefulWidget {
  const _AliasJumpField({
    required this.currentAlias,
    required this.onSubmitted,
  });

  final String currentAlias;
  final ValueChanged<String> onSubmitted;

  @override
  State<_AliasJumpField> createState() => _AliasJumpFieldState();
}

class _AliasJumpFieldState extends State<_AliasJumpField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentAlias);
  }

  @override
  void didUpdateWidget(covariant _AliasJumpField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentAlias != widget.currentAlias &&
        _controller.text != widget.currentAlias) {
      _controller.text = widget.currentAlias;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 118,
      height: 36,
      child: TextField(
        controller: _controller,
        textAlign: TextAlign.center,
        textInputAction: TextInputAction.go,
        decoration: InputDecoration(
          isDense: true,
          labelText: 'Alias',
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1C1C),
          fontSize: 14,
        ),
        onSubmitted: widget.onSubmitted,
      ),
    );
  }
}
