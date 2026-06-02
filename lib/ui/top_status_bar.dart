// Sonar's Dart profile enables contradictory style rules for this file.
// ignore_for_file: always_put_control_body_on_new_line, always_specify_types
// ignore_for_file: avoid_final_parameters, avoid_redundant_argument_values
// ignore_for_file: avoid_types_on_closure_parameters
// ignore_for_file: diagnostic_describe_all_properties
// ignore_for_file: omit_local_variable_types, prefer_double_quotes
// ignore_for_file: prefer_expression_function_bodies, prefer_final_locals
// ignore_for_file: prefer_final_parameters, prefer_single_quotes
// ignore_for_file: public_member_api_docs, unnecessary_final

import 'package:flutter/material.dart';

/// Displays package progress, marker filters, AI status, and navigation.
class TopStatusBar extends StatelessWidget {
  /// Creates the top status and navigation bar.
  const TopStatusBar({
    required int currentIndex,
    required String currentAlias,
    required int gradedCount,
    required int totalStudents,
    required List<String> markerOptions,
    required String selectedMarker,
    required String packagePath,
    required bool aiReady,
    required String aiReadyLabel,
    required String aiProviderStatus,
    required ValueChanged<String> onMarkerChanged,
    required VoidCallback onAiSettings,
    required Future<void> Function() onOpenPackage,
    required VoidCallback onClosePackage,
    required VoidCallback onFirst,
    required VoidCallback onPrevious,
    required VoidCallback onNext,
    required VoidCallback onLast,
    required ValueChanged<String> onAliasSubmitted,
    super.key,
  }) : _currentIndex = currentIndex,
       _currentAlias = currentAlias,
       _gradedCount = gradedCount,
       _totalStudents = totalStudents,
       _markerOptions = markerOptions,
       _selectedMarker = selectedMarker,
       _packagePath = packagePath,
       _aiReady = aiReady,
       _aiReadyLabel = aiReadyLabel,
       _aiProviderStatus = aiProviderStatus,
       _onMarkerChanged = onMarkerChanged,
       _onAiSettings = onAiSettings,
       _onOpenPackage = onOpenPackage,
       _onClosePackage = onClosePackage,
       _onFirst = onFirst,
       _onPrevious = onPrevious,
       _onNext = onNext,
       _onLast = onLast,
       _onAliasSubmitted = onAliasSubmitted;

  final int _currentIndex;
  final String _currentAlias;
  final int _gradedCount;
  final int _totalStudents;
  final List<String> _markerOptions;
  final String _selectedMarker;
  final String _packagePath;
  final bool _aiReady;
  final String _aiReadyLabel;
  final String _aiProviderStatus;
  final ValueChanged<String> _onMarkerChanged;
  final VoidCallback _onAiSettings;
  final Future<void> Function() _onOpenPackage;
  final VoidCallback _onClosePackage;
  final VoidCallback _onFirst;
  final VoidCallback _onPrevious;
  final VoidCallback _onNext;
  final VoidCallback _onLast;
  final ValueChanged<String> _onAliasSubmitted;

  @override
  Widget build(BuildContext context) => Container(
    height: 60,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: const Border(bottom: BorderSide(color: Color(0xFFE0E5E5))),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          offset: const Offset(0, 2),
          blurRadius: 4,
        ),
      ],
    ),
    child: Row(
      children: <Widget>[
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
        _buildIconButton(
          Icons.folder_open_rounded,
          'Open Folder',
          _onOpenPackage,
        ),
        const SizedBox(width: 4),
        _buildIconButton(
          Icons.swap_horiz_rounded,
          'Change Folder',
          _onClosePackage,
        ),
      ],
    ),
  );

  Widget _buildNavigationGroup() => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      _buildIconButton(Icons.first_page_rounded, 'First Student', _onFirst),
      _buildIconButton(
        Icons.chevron_left_rounded,
        'Previous Student',
        _onPrevious,
      ),
      _AliasJumpField(
        currentAlias: _currentAlias,
        onSubmitted: _onAliasSubmitted,
      ),
      _AliasPositionText(
        currentPosition: _totalStudents == 0 ? 0 : _currentIndex + 1,
        totalStudents: _totalStudents,
      ),
      _buildIconButton(Icons.chevron_right_rounded, 'Next Student', _onNext),
      _buildIconButton(Icons.last_page_rounded, 'Last Student', _onLast),
    ],
  );

  Widget _buildProgressPill() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F5F5),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(
          Icons.analytics_outlined,
          size: 16,
          color: Color(0xFF4A5252),
        ),
        const SizedBox(width: 6),
        Text(
          '$_gradedCount graded',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF4A5252),
            fontSize: 13,
          ),
        ),
      ],
    ),
  );

  Widget _buildMarkerDropdown() => SizedBox(
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
            child: Icon(
              Icons.arrow_drop_down_rounded,
              color: Color(0xFF6B7272),
            ),
          ),
          padding: const EdgeInsets.only(left: 12),
          value: _selectedMarker,
          style: const TextStyle(
            color: Color(0xFF1A1C1C),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          items: <DropdownMenuItem<String>>[
            const DropdownMenuItem<String>(
              value: '',
              child: Text('All markers'),
            ),
            ..._markerOptions.map(
              (marker) => DropdownMenuItem<String>(
                value: marker,
                child: Text(marker, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
          onChanged: (value) => _onMarkerChanged(value ?? ''),
        ),
      ),
    ),
  );

  Widget _buildPackageInfo() {
    if (_packagePath.isEmpty) {
      return const SizedBox.shrink();
    }

    // Extract folder name on Windows or Mac.
    final parts = _packagePath.split(RegExp(r'[\\/]'));
    final folderName = parts.isNotEmpty ? parts.last : _packagePath;

    return Expanded(
      flex: 2,
      child: Tooltip(
        message: _packagePath,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            const Icon(
              Icons.topic_outlined,
              size: 16,
              color: Color(0xFF98A2A2),
            ),
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

  Widget _buildAiSettingsButton() => Tooltip(
    message: _aiProviderStatus,
    child: TextButton.icon(
      onPressed: _onAiSettings,
      style: TextButton.styleFrom(
        foregroundColor: _aiReady
            ? const Color(0xFF2E7D7D)
            : const Color(0xFF6B7272),
        backgroundColor: _aiReady
            ? const Color(0xFFE8F3F1)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(_aiReady ? Icons.auto_awesome : Icons.key_rounded, size: 16),
      label: Text(
        _aiReadyLabel,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
  );

  Widget _buildIconButton(
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) => Tooltip(
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

class _AliasPositionText extends StatelessWidget {
  const _AliasPositionText({
    required int currentPosition,
    required int totalStudents,
  }) : _currentPosition = currentPosition,
       _totalStudents = totalStudents;

  final int _currentPosition;
  final int _totalStudents;

  @override
  Widget build(BuildContext context) {
    if (_totalStudents == 0) {
      return const SizedBox(width: 8);
    }

    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 4),
      child: Text(
        '$_currentPosition/$_totalStudents',
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
    required String currentAlias,
    required ValueChanged<String> onSubmitted,
  }) : _currentAlias = currentAlias,
       _onSubmitted = onSubmitted;

  final String _currentAlias;
  final ValueChanged<String> _onSubmitted;

  @override
  State<_AliasJumpField> createState() => _AliasJumpFieldState();
}

class _AliasJumpFieldState extends State<_AliasJumpField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget._currentAlias);
  }

  @override
  void didUpdateWidget(covariant _AliasJumpField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget._currentAlias != widget._currentAlias &&
        _controller.text != widget._currentAlias) {
      _controller.text = widget._currentAlias;
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
  Widget build(BuildContext context) => SizedBox(
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A1C1C),
        fontSize: 14,
      ),
      onSubmitted: widget._onSubmitted,
    ),
  );
}
