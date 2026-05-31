class AIGradingResponse {
  const AIGradingResponse({
    required this.questionScores,
    required this.totalScore,
    required this.comment,
  });
  
  final List<int?> questionScores;
  final int totalScore;
  final String comment;
}
