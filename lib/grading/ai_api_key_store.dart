import 'dart:convert';
import 'dart:io';

class AiSettings {
  const AiSettings({
    this.openRouterApiKey,
    this.openRouterModel = 'meta-llama/llama-3.1-8b-instruct:free',
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
    return AiSettings(
      openRouterApiKey: json['openRouterApiKey'] as String?,
      openRouterModel:
          json['openRouterModel'] as String? ??
          'meta-llama/llama-3.1-8b-instruct:free',
    );
  }

  Map<String, Object?> toJson() => {
    'openRouterApiKey': openRouterApiKey,
    'openRouterModel': openRouterModel,
  };
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
    } catch (_) {
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
