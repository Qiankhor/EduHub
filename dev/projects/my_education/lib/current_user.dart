class CurrentUser {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final String profileImageUrl;
  final String educationLevel;
  final String standardForm;
  final List<String> bookedSessions;

  // Main constructor
  CurrentUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.educationLevel,
    required this.standardForm,
    required this.profileImageUrl,
    required this.bookedSessions,
  });

  // Default constructor for a guest user
  CurrentUser.defaultUser()
      : id = '',
        name = 'Guest',
        email = 'guest@example.com',
        phoneNumber = '',
        educationLevel = 'Unknown',
        standardForm = 'Not Set',
        profileImageUrl = '',
        bookedSessions = [];

  // Factory constructor to create a CurrentUser from Firestore data
  factory CurrentUser.fromMap(String id, Map<String, dynamic> data) {
    return CurrentUser(
      id: id,
      name: data['username'] ?? 'Unknown',
      email: data['email'] ?? '',
      phoneNumber: data['phone'] ?? '',
      educationLevel: data['educationLevel'] ?? 'Unknown',
      standardForm: data['standardForm'] ?? 'Not Set',
      profileImageUrl: data['profileImageUrl'] ?? '',
      bookedSessions: List<String>.from(data['bookedSessions'] ?? []),
    );
  }

  // Method to convert a CurrentUser instance to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'username': name,
      'email': email,
      'phone': phoneNumber,
      'educationLevel': educationLevel,
      'standardForm': standardForm,
      'profileImageUrl': profileImageUrl,
      'bookedSessions': bookedSessions,
    };
  }
}
