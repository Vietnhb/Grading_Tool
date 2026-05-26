import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lecturer_grading_tool/main.dart';

void main() {
  testWidgets('shows package drop prompt', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GradingToolApp()));

    expect(find.text('Drop an exam package folder'), findsOneWidget);
    expect(find.text('Select Folder'), findsOneWidget);
  });
}
