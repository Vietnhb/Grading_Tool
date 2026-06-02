class AppConstants {
  AppConstants._();

  // AI Grading Settings
  static const String defaultAiModel = 'openai/gpt-oss-120b:free';
  static const List<String> legacyDefaultAiModels = [
    'meta-llama/llama-3.1-8b-instruct:free',
    'openai/gpt-oss-20b:free',
    'gemma-4-31b-it:free',
    'nvidia/nemotron-3-super-120b-a12b:free',
  ];
  static const Duration aiRequestTimeout = Duration(seconds: 90);
  static const int aiMaxTokens = 4096;
  static const double aiTemperature = 0;
  static const int aiBatchChunkSize = 1;
  static const List<Duration> aiTransientRetryDelays = [
    Duration(seconds: 3),
    Duration(seconds: 8),
    Duration(seconds: 15),
  ];
  static const String openRouterChatCompletionsUrl =
      'https://openrouter.ai/api/v1/chat/completions';
  static const String openRouterReferer =
      'http://localhost/lecturer-grading-tool';
  static const String openRouterTitle = 'Lecturer Grading Tool';

  // OpenRouter API Key Validation
  static const String openRouterKeyPrefix = 'sk-or-v1-';
  static const int openRouterKeyMinLength = 20;

  // OCR Settings
  static const String ocrLanguage = 'en-US';
  static const int ocrMinTextLength = 200;
  static const int ocrMinQuestionHeadings = 1;
  static const int ocrMinLineCount = 3;
  static const String ocrTempFolderPrefix = 'lecturer_grading_ocr_';
  static const String ocrProcessedImageName = 'question_alpha_ocr.png';
  static const String ocrScriptFileName = 'question_ocr.ps1';

  // File Extensions
  static const List<String> supportedImageExtensions = [
    '.png',
    '.jpg',
    '.jpeg',
  ];
  static const String studentSolutionsFolder = 'Student_Solutions';
  static const String markInputExtension = '.xlsx';
  static const String gradingGuideExtension = '.docx';
  static const String submissionExtension = '.txt';
  static const String gradingAuditFileName = 'grading_log.json';
}
