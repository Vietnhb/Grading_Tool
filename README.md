# Grading Rubric Parser

Small Dart library to parse DOCX grading guides into a JSON rubric and generate LLM prompts.

Usage:

1. Install dependencies:

```bash
dart pub get
```

2. Run example:

```bash
dart run example/main.dart path/to/PMG201c_SP26_2ndFE_PE_Grading_Guides.docx [student_answer.txt]
```

Outputs `rubric.json` next to the docx and optional `prompt.txt` when a student answer is provided.

Notes:

- The parser uses heuristics and may require manual review of the generated JSON. You can extend the item/score extraction rules in `lib/rubric_parser.dart`.
- Designed to integrate into a Flutter app: call `parseDocxRubric` from your UI/backend and then run LLM prompt generation or manual grading flows.

## Flutter app

There's a small example Flutter desktop app in `flutter_app/` that provides a GUI to select or drag a folder. It scans for `.docx` (and `.xml`) files and shows a preview of the parsed rubric for the first file.

To run the Flutter app (desktop):

```bash
cd flutter_app
flutter pub get
flutter run -d windows
```
