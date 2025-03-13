import 'dart:convert';
import 'package:my_education/profile/edit_field_screen.dart';
import 'package:my_education/profile/support_queries_screen.dart';
import 'package:my_education/profile/tutor_profile/qualification_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class TutorProfileScreen extends StatefulWidget {
  const TutorProfileScreen({super.key});

  @override
  _TutorProfileScreenState createState() => _TutorProfileScreenState();
}

class _TutorProfileScreenState extends State<TutorProfileScreen> {
  String? _name;
  String? _email;
  String? _phoneNumber;
  String? _subject;
  String? _level;
  String? _qualification;
  String? _paymentMethod;
  String? _profileImageUrl;
  final ImagePicker _picker = ImagePicker();
  String? _qualificationStatus;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _fetchUserData();
      } else {
        print("User not logged in");
      }
    });
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          setState(() {
            _name = data['username'];
            _email = data['email'];
            _phoneNumber = data['phone'];
          });
        } else {
          print('Document does not exist');
        }

        DocumentSnapshot qualificationDoc = await FirebaseFirestore.instance
            .collection('qualifications')
            .doc(user.uid)
            .get();

        if (qualificationDoc.exists) {
          final qualificationData =
              qualificationDoc.data() as Map<String, dynamic>? ?? {};
          setState(() {
            _qualificationStatus =
                qualificationData['qualificationStatus'] ?? 'Not Set';
            _level = qualificationData['level'] ?? 'Not Set';
            _subject = qualificationData['subject'] ?? 'Not Set';
            _profileImageUrl = qualificationData['profileImageUrl'] ?? null;
          });
        } else {
          print('Qualification document does not exist');
        }
      } catch (e) {
        print('Error fetching user data: $e');
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.2.2:5000/upload'),
      );

      var file = await http.MultipartFile.fromPath('profileImage', image.path);
      request.files.add(file);

      var response = await request.send();

      if (response.statusCode == 200) {
        var responseData = await http.Response.fromStream(response);
        var data = jsonDecode(responseData.body);
        String imageUrl = data['imageUrl'];

        await FirebaseFirestore.instance
            .collection('qualifications')
            .doc(user.uid)
            .update({'profileImageUrl': imageUrl});

        if (mounted) {
          setState(() {
            _profileImageUrl = imageUrl;
          });
        }
      } else {
        print(
            'Failed to upload image: ${response.statusCode}'); // Add this line to check response details
        Fluttertoast.showToast(
          msg: "Failed to upload image. Status code: ${response.statusCode}",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (e) {
      print("Error uploading image: $e");
      Fluttertoast.showToast(
        msg: "Failed to upload image: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6E6FA),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _pickAndUploadImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: _profileImageUrl != null
                          ? NetworkImage(_profileImageUrl!)
                          : const AssetImage('assets/blank_profile.png')
                              as ImageProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: const Align(
                    alignment: Alignment.bottomRight,
                    child: Icon(
                      Icons.camera_alt,
                      color: Color.fromARGB(255, 0, 0, 0),
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _name ?? 'Loading...',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit,
                            color: Colors.black), // Edit icon
                        onPressed: () {
                          _navigateToEditScreen(
                              'Username'); // Navigate to edit screen for Name
                        },
                      ),
                    ],
                  ),
                  if (_qualificationStatus == 'Verified') ...[
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified,
                          color: Colors.blue,
                          size: 20,
                        ),
                        SizedBox(width: 4), // Small space between icon and text
                        Text(
                          'Verified Tutor',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              _buildProfileListItem(
                  context, 'Email', _email ?? 'Loading...', false),
              _buildProfileListItem(
                  context, 'Phone Number', _phoneNumber ?? 'Loading...', true),
              _buildProfileListItem(context, 'Teaching Level',
                  _level ?? 'Select teaching level', true),
              _buildProfileListItem(
                  context, 'Subject', _subject ?? 'Select subject', true),
              _buildProfileListItem(
                context,
                'Qualification',
                _qualificationStatus == 'Pending'
                    ? 'Pending Verification'
                    : _qualificationStatus == 'Verified'
                        ? 'Verified'
                        : 'Not Set',
                true,
              ),
              // _buildProfileListItem(
              //     context, 'Payment Method', _paymentMethod ?? 'Not Set', true),
              _buildSupportQueriesSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileListItem(
      BuildContext context, String title, String subtitle, bool editable) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        tileColor: Colors.white,
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          title == 'Qualification'
              ? _qualificationStatus ?? 'Not Set'
              : subtitle,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        trailing: editable
            ? Icon(Icons.arrow_forward_ios, color: Colors.grey[600], size: 16)
            : null, // Conditionally show arrow based on 'editable'
        onTap: () {
          if (title == 'Phone Number' || title == 'Qualification') {
            _navigateToEditScreen(title);
          } else if (title == 'Teaching Level') {
            _showTeachingLevelBottomSheet();
          } else if (title == 'Subject') {
            _showSubjectBottomSheet();
          }
        },
      ),
    );
  }

  void _navigateToEditScreen(String field) {
    if (field == 'Qualification') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => QualificationScreen()),
      ).then((_) => _fetchUserData());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditFieldScreen(
              field: field, currentValue: _getCurrentFieldValue(field)),
        ),
      ).then((_) => _fetchUserData());
    }
  }

  String _getCurrentFieldValue(String field) {
    switch (field) {
      case 'Email':
        return _email ?? '';
      case 'Phone Number':
        return _phoneNumber ?? '';
      case 'Qualification':
        return _qualification ?? '';
      default:
        return '';
    }
  }

  void _showTeachingLevelBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select Teaching Level',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ListTile(
                title: const Text('Primary'),
                onTap: () {
                  _updateTeachingLevel('Primary');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Secondary'),
                onTap: () {
                  _updateTeachingLevel('Secondary');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _updateTeachingLevel(String level) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final qualificationDoc = await FirebaseFirestore.instance
        .collection('qualifications')
        .doc(user.uid)
        .get();

    if (!qualificationDoc.exists) {
      // If qualifications document doesn't exist, create it
      await FirebaseFirestore.instance
          .collection('qualifications')
          .doc(user.uid)
          .set({
        'qualificationStatus': 'Not Set', // Default status
        'level': level,
        'subject': 'Not Set', // Default subject
        'profileImageUrl': null, // Default profile image URL
      });
    } else {
      String? currentProfileImageUrl =
          qualificationDoc.data()?['profileImageUrl'];
      // Update the existing qualifications document
      await FirebaseFirestore.instance
          .collection('qualifications')
          .doc(user.uid)
          .update({
        'level': level,
        'profileImageUrl': currentProfileImageUrl,
      });
    }

    setState(() {
      _level = level;
    });
  }

  void _showSubjectBottomSheet() {
    List<String> subjects = _level == 'Primary'
        ? ['English', 'BM', 'Mathematics', 'History', 'Geography']
        : [
            'English',
            'BM',
            'Mathematics',
            'Science',
            'AddMaths',
            'Chemistry',
            'Biology',
            'Physics',
            'History',
            'Geography'
          ];

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 400, // Adjust height as needed
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Select Subject',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                for (var subject in subjects)
                  ListTile(
                    title: Text(subject),
                    onTap: () {
                      _updateSubject(subject);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _updateSubject(String subject) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final qualificationDoc = await FirebaseFirestore.instance
        .collection('qualifications')
        .doc(user.uid)
        .get();

    if (!qualificationDoc.exists) {
      // If qualifications document doesn't exist, create it
      await FirebaseFirestore.instance
          .collection('qualifications')
          .doc(user.uid)
          .set({
        'qualificationStatus': 'Not Set', // Default status
        'level': 'Not Set', // Default level
        'subject': subject,
        'profileImageUrl': null, // Default profile image URL
      });
    } else {
      String? currentProfileImageUrl =
          qualificationDoc.data()?['profileImageUrl'];
      // Update the existing qualifications document
      await FirebaseFirestore.instance
          .collection('qualifications')
          .doc(user.uid)
          .update({
        'subject': subject,
        'profileImageUrl': currentProfileImageUrl,
      });
    }

    setState(() {
      _subject = subject;
    });
  }

  Widget _buildSupportQueriesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        tileColor: Colors.white,
        title: const Text(
          'Support & Queries',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        trailing:
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SupportQueriesScreen()),
          );
        },
      ),
    );
  }
}
