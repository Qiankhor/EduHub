class QuizSet {
  final String categoryName;
  final String subjectName;
  final String setName;
  int questionsCount; // Make it mutable
  final String providerName;
  final String providerId; // Added providerId field
  final Map<dynamic, dynamic> setData;
  int totalSetCount; // Mutable field for total set count
  int totalSubjectCount;

  QuizSet(
      {required this.categoryName,
      required this.subjectName,
      required this.setName,
      required this.questionsCount,
      required this.providerName,
      required this.providerId, // Added to constructor
      required this.setData,
      this.totalSetCount = 0, // Initialize with 0 by default
      this.totalSubjectCount = 0});
}
