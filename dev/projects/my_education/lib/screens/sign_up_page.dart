import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_education/models/Teachers.dart';
import 'package:my_education/screens/home_page.dart';
import 'package:my_education/screens/login_page.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  bool _passwordVisible = false;

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.black,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  Future<String?> generateDeviceRecognitionToken() async {
    try {
      String? deviceToken = await FirebaseMessaging.instance.getToken();
      return deviceToken; // Return the device token
    } catch (e) {
      print('Failed to generate device token: $e');
      return null;
    }
  }

  void _submitForm() async {
    String fullName = fullNameController.text.trim();
    String email = emailController.text.trim();
    String password = passwordController.text.trim();
    String confirmPassword = confirmPasswordController.text.trim();

    if (fullName.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showToast('Please fill in all fields.');
      return;
    }

    int? age; // Declare age as nullable
    try {
      age = int.parse(ageController.text.trim()); // Attempt to parse age
    } catch (e) {
      _showToast('Please enter a valid age.'); // Show error message for invalid input
      return;
    }

    if (age == null || age < 0) { // Check if age is negative or null
      _showToast('Please enter a valid age.');
      return;
    }

    if (password != confirmPassword) {
      _showToast('Passwords do not match.');
      return;
    }

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        String? deviceToken = await generateDeviceRecognitionToken();
        
        if (deviceToken != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'fullName': fullName,
            'email': email,
            'age': age,
            'userType': 'student',
            'status': 'unblock',
            'points': 0,
            'deviceToken': deviceToken, // Store device token here
          });

          _showToast('Registration successful.');
            Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(
              Teacher(
                name: '',
                university: '',
                imageAsset: '',
                rating: 0.0,
                reviews: 0,
              ),
            ),
          ),
        );
        } else {
          _showToast('Failed to retrieve device token.');
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        _showToast('The password provided is too weak.');
      } else if (e.code == 'email-already-in-use') {
        _showToast('The account already exists for that email.');
      } else {
        _showToast('Failed to register: ${e.message}');
      }
    } catch (e) {
      _showToast('An unknown error occurred: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 94, 17, 70),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: EdgeInsets.fromLTRB(8, 0, 8, 89),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    'Sign Up',
                    style: GoogleFonts.getFont(
                      'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 40,
                      height: 1.5,
                      color: Colors.orange[900],
                    ),
                  ),
                ),
              ),
              buildTextField('Full Name', fullNameController),
              buildTextField('Email', emailController,keyboardType: TextInputType.emailAddress),  
              buildTextField('Age', ageController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
              buildPasswordTextField('Password', passwordController),
              buildPasswordTextField('Confirm Password', confirmPasswordController),
              buildSignUpButton(),
              buildLoginLink(),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTextField(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text, List<TextInputFormatter>? inputFormatters}) {
    return Container(
      margin: EdgeInsets.fromLTRB(0, 0, 0, 24),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 14.0, color: Colors.grey),
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.orange.shade700, width: 2.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey, width: 1.0),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        ),
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
      ),
    );
  }

  Widget buildPasswordTextField(String label, TextEditingController controller) {
    return Container(
      margin: EdgeInsets.fromLTRB(0, 0, 0, 24),
      child: TextField(
        controller: controller,
        obscureText: !_passwordVisible,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 14.0, color: Colors.grey),
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.orange.shade700, width: 2.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey, width: 1.0),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          suffixIcon: IconButton(
            icon: Icon(
              _passwordVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _passwordVisible = !_passwordVisible;
              });
            },
          ),
        ),
        keyboardType: TextInputType.visiblePassword,
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
      ),
    );
  }

  Widget buildSignUpButton() {
    return Container(
      margin: EdgeInsets.fromLTRB(0, 32, 0, 15),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.shade700,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        onPressed: _submitForm,
        child: Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 12),
          child: Align(
            alignment: Alignment.center,
            child: Text(
              'Sign Up',
              style: GoogleFonts.getFont(
                'Poppins',
                fontWeight: FontWeight.w500,
                fontSize: 14,
                height: 1.4,
                color: Color(0xFFFFFFFF),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          textAlign: TextAlign.center,
          style: GoogleFonts.getFont(
            'Poppins',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            height: 1.4,
            color: Color(0xFF828282),
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => LoginPage()),
            );
          },
          child: Text(
            'Log In',
            textAlign: TextAlign.center,
            style: GoogleFonts.getFont(
              'Poppins',
              fontWeight: FontWeight.w500,
              fontSize: 14,
              height: 1.4,
              color: Colors.orange.shade700,
            ),
          ),
        ),
      ],
    );
  }
}
