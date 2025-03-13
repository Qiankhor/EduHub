class QuizSet {
  final String categoryName;
  final String subjectName;
  final String setName;
  int questionsCount; // Make it mutable
  final String providerName;
  final Map<dynamic, dynamic> setData;
  int totalSetCount; // Mutable field for total set count
  int totalSubjectCount;

  QuizSet({
    required this.categoryName,
    required this.subjectName,
    required this.setName,
    required this.questionsCount,
    required this.providerName,
    required this.setData,
    this.totalSetCount = 0, // Initialize with 1 by default
    this.totalSubjectCount = 0
  });
}
