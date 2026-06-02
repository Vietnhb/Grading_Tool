class AppConstants {
  AppConstants._();

  // AI Grading Settings
  static const String defaultAiModel = 'openai/gpt-oss-120b:free';
  static const Duration aiRequestTimeout = Duration(seconds: 90);
  static const int aiMaxTokens = 4096;
  static const double aiTemperature = 0;

  // OpenRouter API
  static const String openRouterKeyPrefix = 'sk-or-v1-';
  static const int openRouterKeyMinLength = 20;
  static const String openRouterApiUrl =
      'https://openrouter.ai/api/v1/chat/completions';
  static const String openRouterReferer =
      'https://lecturer-grading-tool.app';
  static const String openRouterAppTitle = 'Lecturer Grading Tool';
  static const int apiKeyPreviewMinLength = 8;

  // Deprecated AI models — auto-migrate saved settings to defaultAiModel.
  static const List<String> deprecatedAiModels = [
    'meta-llama/llama-3.1-8b-instruct:free',
    'openai/gpt-oss-20b:free',
  ];

  // OCR Settings
  static const String ocrLanguage = 'en-US';
  static const int ocrMinTextLength = 200;
  static const int ocrMinQuestionHeadings = 1;
  static const int ocrMinLineCount = 3;

  // Excel Layout Detection
  static const int maxHeaderScanRows = 20;

  // AI Validation
  static const int minSubstantialAnswerLength = 200;

  // Rubric Parsing — keywords to detect "common mistakes" section.
  static const List<String> commonMistakesKeywords = [
    'lỗi thường gặp',
    'common mistake',
  ];

  // File Extensions
  static const List<String> supportedImageExtensions = ['.png', '.jpg', '.jpeg'];
  static const String studentSolutionsFolder = 'Student_Solutions';
  static const String markInputExtension = '.xlsx';
  static const String gradingGuideExtension = '.docx';
  static const String submissionExtension = '.txt';
}