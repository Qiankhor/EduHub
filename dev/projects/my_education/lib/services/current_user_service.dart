import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_education/current_user.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch the current user by their UID (this should be passed as a parameter)
  Future<CurrentUser?> fetchCurrentUser(String userId) async {
    try {
      DocumentSnapshot docSnapshot =
          await _firestore.collection('users').doc(userId).get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;

        // Ensure bookedSessions is a list (even if it's empty)
        List<String> bookedSessions =
            List<String>.from(data['bookedSessions'] ?? []);

        // Return the CurrentUser object
        return CurrentUser(
          id: docSnapshot.id,
          name: data['username'] ?? 'Unknown',
          email: data['email'] ?? '',
          phoneNumber: data['phone'] ?? '',
          educationLevel: data['educationLevel'] ?? 'Unknown',
          standardForm: data['standardForm'] ?? 'Not Set',
          profileImageUrl: data['profileImageUrl'] ?? '',
          bookedSessions: bookedSessions,
        );
      } else {
        print('User not found');
        return null;
      }
    } catch (e) {
      print('Error fetching current user: $e');
      return null;
    }
  }
}
