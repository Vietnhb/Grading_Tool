class AppConstants {
  AppConstants._();

  // AI Grading Settings
  static const String defaultAiModel = 'openai/gpt-oss-120b:free';
  static const Duration aiRequestTimeout = Duration(seconds: 90);
  static const int aiMaxTokens = 4096;
  static const double aiTemperature = 0;

  // OpenRouter API Key Validation
  static const String openRouterKeyPrefix = 'sk-or-v1-';
  static const int openRouterKeyMinLength = 20;

  // OCR Settings
  static const String ocrLanguage = 'en-US';
  static const int ocrMinTextLength = 200;
  static const int ocrMinQuestionHeadings = 1;
  static const int ocrMinLineCount = 3;

  // File Extensions
  static const List<String> supportedImageExtensions = ['.png', '.jpg', '.jpeg'];
  static const String studentSolutionsFolder = 'Student_Solutions';
  static const String markInputExtension = '.xlsx';
  static const String gradingGuideExtension = '.docx';
  static const String submissionExtension = '.txt';
}