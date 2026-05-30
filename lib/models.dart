import 'dart:convert';

class RubricItem {
  final String code;
  final String name;
  final num? maxScore;

  RubricItem({required this.code, required this.name, this.maxScore});

  Map<String, dynamic> toJson() => {'name': name, 'max_score': maxScore};
}

class RubricRequest {
  final String id;
  final String title;
  final num? total;
  final Map<String, RubricItem> items;

  RubricRequest({
    required this.id,
    required this.title,
    this.total,
    Map<String, RubricItem>? items,
  }) : items = items ?? {};

  Map<String, dynamic> toJson() => {
    'title': title,
    'total': total,
    'items': items.map((k, v) => MapEntry(k, v.toJson())),
  };
}

class Rubric {
  final Map<String, RubricRequest> requests;

  Rubric({Map<String, RubricRequest>? requests}) : requests = requests ?? {};

  Map<String, dynamic> toJson() =>
      requests.map((k, v) => MapEntry(k, v.toJson()));

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}
