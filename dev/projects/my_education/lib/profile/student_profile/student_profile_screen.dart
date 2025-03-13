import 'dart:convert';
import 'package:my_education/profile/edit_field_screen.dart';
import 'package:my_education/profile/payment_method_screen.dart';
import 'package:my_education/profile/student_profile/online_learning_resources_screen.dart';
import 'package:my_education/profile/student_profile/progress_tracking/progress_tracking_screen.dart';
import 'package:my_education/profile/support_queries_screen.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  _StudentProfileScreenState createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  String? _name;
  String? _email;
  String? _phoneNumber;
  String? _educationLevel;
  String? _standardForm;
  String? _paymentMethod;
  String? _profileImageUrl;
  final ImagePicker _picker = ImagePicker();

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fetchUserData();
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
            _educationLevel = data['level'];
            _standardForm = data['standardForm'];
            _paymentMethod = data['paymentMethod'];
            _profileImageUrl = data['profileImageUrl'];
          });
        } else {
          print('Document does not exist');
        }
      } catch (e) {
        print('Error fetching user data: $e');
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Pick an image from the gallery
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
            'http://10.0.2.2:5000/upload'), // Ensure this is correct for your environment
      );

      // Attach the image file
      var file = await http.MultipartFile.fromPath(
        'profileImage', // This should match the name used in multer
        image.path,
      );
      request.files.add(file);

      // Send the request
      var response = await request.send();

      // Check the response status
      if (response.statusCode == 200) {
        // Parse the response
        var responseData = await http.Response.fromStream(response);
        var data = jsonDecode(responseData.body);
        String imageUrl = data['imageUrl'];

        // Update Firestore with the new image URL
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'profileImageUrl': imageUrl});

        setState(() {
          _profileImageUrl = imageUrl;
        });
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
                  width: 120, // Double the radius
                  height: 120, // Double the radius
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: _profileImageUrl != null &&
                              _profileImageUrl!.isNotEmpty
                          ? NetworkImage(_profileImageUrl!) as ImageProvider
                          : const AssetImage('assets/blank_profile.png'),
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
              const SizedBox(height: 20),
              _buildProfileListItem(
                  context, 'Email', _email ?? 'Loading...', false),
              _buildProfileListItem(
                  context, 'Phone Number', _phoneNumber ?? 'Loading...', true),
              _buildProfileListItem(context, 'Education Level',
                  _educationLevel ?? 'Set Education Level', true),
              _buildProfileListItem(context, 'Standard/Form',
                  _standardForm ?? 'Set Standard/Form', true),
              // _buildProfileListItem(context, 'Payment Method',
              //     _paymentMethod ?? 'Set Payment Method', true),
              _buildSection('Progress Tracking', ProgressTrackingScreen()),
              _buildSection(
                  'Online Learning Resources', OnlineLearningResourcesScreen()),
              _buildSection('User Support & Queries', SupportQueriesScreen()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileListItem(
    BuildContext context,
    String title,
    String subtitle,
    bool editable, // Added the editable parameter
  ) {
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
          subtitle,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        trailing: editable
            ? Icon(Icons.arrow_forward_ios, color: Colors.grey[600], size: 16)
            : null, // Conditionally show arrow based on 'editable'
        onTap: () {
          if (editable) {
            if (title == 'Phone Number' || title == 'Payment Method') {
              _navigateToEditScreen(title);
            } else if (title == 'Education Level') {
              _showEducationLevelBottomSheet();
            } else if (title == 'Standard/Form') {
              _showStandardFormBottomSheet();
            }
          }
        },
      ),
    );
  }

  Widget _buildSection(String title, Widget screen) {
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
        trailing:
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => screen),
          );
        },
      ),
    );
  }

  void _navigateToEditScreen(String field) {
    if (field == 'Payment Method') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PaymentMethodScreen()),
      ).then((_) => _fetchUserData());
    } else if (field == 'Progress Tracking') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProgressTrackingScreen()),
      ).then((_) => _fetchUserData());
    } else if (field == 'Online Learning Resources') {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => OnlineLearningResourcesScreen()),
      ).then((_) => _fetchUserData());
    } else if (field == 'User Support & Queries') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SupportQueriesScreen()),
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
      default:
        return '';
    }
  }

  void _showEducationLevelBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select Education Level',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ListTile(
                title: const Text('Primary'),
                onTap: () {
                  _updateEducationLevel('Primary');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Secondary'),
                onTap: () {
                  _updateEducationLevel('Secondary');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _updateEducationLevel(String level) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);

    // Update the user's document with the selected education level
    await doc.update({
      'level': level,
    });

    setState(() {
      _educationLevel = level;
    });
  }

  void _updateStandardForm(String standardForm) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);

    // Update the user's document with the selected standard/form
    await doc.update({
      'standardForm': standardForm,
    });

    setState(() {
      _standardForm = standardForm;
    });
  }

  void _showStandardFormBottomSheet() {
    List<String> standardForms = _educationLevel == 'Primary'
        ? [
            'Standard 1',
            'Standard 2',
            'Standard 3',
            'Standard 4',
            'Standard 5',
            'Standard 6'
          ]
        : [
            'Form 1',
            'Form 2',
            'Form 3',
            'Form 4',
            'Form 5',
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
                const Text('Select Standard/Form',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                for (var standardForm in standardForms)
                  ListTile(
                    title: Text(standardForm),
                    onTap: () {
                      _updateStandardForm(standardForm);
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
}
