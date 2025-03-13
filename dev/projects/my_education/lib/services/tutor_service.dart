import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_education/tutor.dart';
import 'package:intl/intl.dart';

class TutorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper function to calculate the age based on the date of birth
  int calculateAge(String dateOfBirth) {
    final DateTime dob = DateFormat('MM/dd/yyyy').parse(dateOfBirth);
    final DateTime now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  // Fetch verified tutors from Firestore and map to Tutor objects
  Future<List<Tutor>> fetchTutors() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('qualifications')
          .where('qualificationStatus',
              isEqualTo: 'Verified') // Add level filter
          .get();

      // Map documents to Tutor objects with safe casting and null checks
      List<Tutor> tutorList = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>?;

        if (data != null) {
          String dob = data['dateOfBirth'] ?? '';

          // Create a Tutor object from Firestore data
          return Tutor(
            id: doc.id, // Use the document ID as the tutor ID
            name: data['name'] ?? 'Unknown',
            location: data['location'] ?? 'Unknown',
            subject: data['subject'] ?? 'Unknown',
            level: data['level'] ?? 'Unknown',
            profileImageUrl: data['profileImageUrl'],
            rating: data['rating'] != null
                ? (data['rating'] as num).toDouble()
                : null,
            reviews: data['reviews'] != null
                ? List<String>.from(data['reviews'])
                : [],
            education: data['highestQualification'] ?? 'Not specified',
            experience: (data['yearsOfExperience'] as int?) ?? 0,
            gender: data['gender'] ?? 'Not specified',
            ratePerHour: (data['ratePerHour'] as num?)?.toDouble() ?? 0.0,
            availableDays: data['availableDays'] != null
                ? List<String>.from(data['availableDays'])
                : [],
            availableTimeSlots: data['availableTimeSlots'] != null
                ? List<int>.from(data['availableTimeSlots'])
                : [],
            dateOfBirth: dob,
            highestQualification:
                data['highestQualification'] ?? 'Not specified',
            institutionName: data['institutionName'] ?? 'Not specified',
            qualificationStatus: data['qualificationStatus'] ?? 'Not specified',
            yearOfGraduation: data['yearOfGraduation'] ?? 'Not specified',
            aboutMe: data['about'] ?? '',
            age: dob.isNotEmpty ? calculateAge(dob) : 0,
          );
        } else {
          throw Exception('Failed to cast Firestore data');
        }
      }).toList();

      return tutorList;
    } catch (e) {
      print('Error fetching tutors: $e');
      return [];
    }
  }
}
