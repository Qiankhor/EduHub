class Tutor {
  final String id;
  final String name;
  final int age; // This will be calculated
  final String gender;
  final String level;
  final String subject;
  final String? profileImageUrl;
  final double? rating; // Change to nullable for flexibility
  final String education;
  final int experience;
  final String location;
  final String aboutMe;
  final double ratePerHour;
  final List<String> availableDays;
  final List<int> availableTimeSlots;
  final String dateOfBirth; // Store dateOfBirth
  final String highestQualification;
  final String institutionName;
  final String qualificationStatus;
  final String yearOfGraduation;
  List<String>? reviews; // Initialize as a nullable list

  Tutor({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.level,
    required this.subject,
    this.profileImageUrl,
    this.rating, // Optional rating
    required this.education,
    required this.experience,
    required this.location,
    required this.aboutMe,
    required this.ratePerHour,
    required this.availableDays,
    required this.availableTimeSlots,
    required this.dateOfBirth,
    required this.highestQualification,
    required this.institutionName,
    required this.qualificationStatus,
    required this.yearOfGraduation,
    this.reviews, // Optional reviews
  });
}
