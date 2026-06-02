import 'dart:convert';
import 'dart:io';

import '../core/constants.dart';

class AiSettings {
  const AiSettings({
    this.openRouterApiKey,
    this.openRouterModel = AppConstants.defaultAiModel,
  });

  final String? openRouterApiKey;
  final String openRouterModel;

  bool get hasOpenRouterKey =>
      openRouterApiKey != null && openRouterApiKey!.trim().isNotEmpty;

  AiSettings copyWith({
    String? openRouterApiKey,
    bool clearOpenRouterApiKey = false,
    String? openRouterModel,
  }) {
    return AiSettings(
      openRouterApiKey: clearOpenRouterApiKey
          ? null
          : openRouterApiKey ?? this.openRouterApiKey,
      openRouterModel: openRouterModel ?? this.openRouterModel,
    );
  }

  factory AiSettings.fromJson(Map<Object?, Object?> json) {
    final savedModel = json['openRouterModel'] as String?;
    final shouldUseDefault =
        savedModel == null ||
        AppConstants.deprecatedAiModels.contains(savedModel);
    final model = shouldUseDefault ? AppConstants.defaultAiModel : savedModel;
    return AiSettings(
      openRouterApiKey: json['openRouterApiKey'] as String?,
      openRouterModel: model,
    );
  }

  Map<String, Object?> toJson() => {
    'openRouterApiKey': openRouterApiKey,
    'openRouterModel': openRouterModel,
  };
}

bool isValidOpenRouterApiKey(String? apiKey) {
  final value = apiKey?.trim() ?? '';
  return value.startsWith(AppConstants.openRouterKeyPrefix) && value.length > AppConstants.openRouterKeyMinLength;
}

class AiApiKeyStore {
  const AiApiKeyStore();

  AiSettings read() {
    final file = _settingsFile();
    if (file == null || !file.existsSync()) {
      return const AiSettings();
    }
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is Map) {
        return AiSettings.fromJson(decoded);
      }
    } catch (error) {
      stderr.writeln('[AiApiKeyStore] Failed to read settings: $error');
      return const AiSettings();
    }
    return const AiSettings();
  }

  Future<void> save(AiSettings settings) async {
    final file = _settingsFile();
    if (file == null) {
      return;
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(settings.toJson()), flush: true);
  }

  Future<void> clear() async {
    final file = _settingsFile();
    if (file != null && await file.exists()) {
      await file.delete();
    }
  }

  File? _settingsFile() {
    final root =
        Platform.environment['APPDATA'] ??
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'];
    if (root == null || root.trim().isEmpty) {
      return null;
    }
    return File(
      '$root${Platform.pathSeparator}lecturer_grading_tool${Platform.pathSeparator}ai_settings.json',
    );
  }
}
