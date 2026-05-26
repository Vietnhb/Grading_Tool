import 'dart:io';

import 'package:path/path.dart' as p;

String aliasFromFile(File file) => p.basenameWithoutExtension(file.path).trim();

int compareAliases(String left, String right) {
  final leftNumber = int.tryParse(left);
  final rightNumber = int.tryParse(right);
  if (leftNumber != null && rightNumber != null) {
    return leftNumber.compareTo(rightNumber);
  }
  return left.toLowerCase().compareTo(right.toLowerCase());
}

String extensionOf(FileSystemEntity entity) {
  return p.extension(entity.path).toLowerCase();
}
