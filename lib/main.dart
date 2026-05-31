import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/grading_home_view.dart';

void main() {
  // Khoi dong Riverpod scope, sau do vao man hinh chinh GradingHomeView.
  runApp(const ProviderScope(child: GradingToolApp()));
}

class GradingToolApp extends StatelessWidget {
  const GradingToolApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Cau hinh app/theme. Flow tiep theo: GradingHomeView se quyet dinh
    // hien man chon package hay workspace cham diem.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PMG201c Grading Tool',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F5E5E),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        visualDensity: VisualDensity.compact,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      home: const GradingHomeView(),
    );
  }
}
