import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_education/profile/student_profile/student_profile_screen.dart';
import 'package:my_education/profile/tutor_profile/tutor_profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_education/screens/login_page.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String userRole = ''; // To store the user's role

  @override
  void initState() {
    super.initState();
    fetchUserRole();
  }

  // Fetch the user's role from Firestore based on the current user's ID
  Future<void> fetchUserRole() async {
    try {
      // Get the current user's ID
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Fetch the user document from Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        setState(() {
          userRole = userDoc['role'] ?? ''; // Get the role field from Firestore
        });
      }
    } catch (e) {
      print('Error fetching user role: $e');
    }
  }

  // Function to handle logout
  void _logout() async {
    try {
      await FirebaseAuth.instance.signOut(); // Sign out from Firebase
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()),
        (route) => false,
      ); // Navigate to LoginScreen and clear navigation history
    } catch (e) {
      print('Error logging out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDDDFFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Center(
          child: Text('Profile', style: TextStyle(color: Colors.black)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: _logout, // Call logout function
          ),
        ],
        elevation: 0,
      ),
      body: userRole.isEmpty
          ? const Center(
              child:
                  CircularProgressIndicator()) // Show loading indicator while fetching
          : userRole == 'Student'
              ? const StudentProfileScreen()
              : const TutorProfileScreen(),
    );
  }
}
