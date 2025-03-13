import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_education/screens/change_password.dart';
import 'package:my_education/screens/home_page.dart';
import 'package:my_education/models/Teachers.dart';
import 'package:my_education/screens/sign_up_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _passwordVisible = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> generateDeviceRecognitionToken(String uid) async {
    try {
      FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;
      String? deviceToken = await firebaseMessaging.getToken();
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'deviceToken': deviceToken,
      });
      print("Device token generated: $deviceToken");
    } catch (e) {
      print('Failed to generate device token: $e');
    }
  }

  Future<bool> isConnected() async {
    try {
      final result = await http.get(Uri.parse('https://www.google.com'));
      if (result.statusCode == 200) {
        return true; // Network is connected
      }
    } catch (e) {
      print('No internet connection: $e');
    }
    return false; // No internet connection
  }

  Future<void> _login() async {
    // Check network connectivity
    bool isConnectedToNetwork = await isConnected();
    if (!isConnectedToNetwork) {
      Fluttertoast.showToast(
        msg: "No internet connection. Please connect to the internet.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.black,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return; // Stop the function from proceeding
    }

    // Attempt login
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = _auth.currentUser;

      if (user != null) {
        // Generate device recognition token after login
        await generateDeviceRecognitionToken(user.uid);

        // Navigate to HomePage if login is successful
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
      }
    } catch (e) {
      print('Failed to login: $e');
      Fluttertoast.showToast(
        msg: "Login failed. Please check your email and password.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.black,
        textColor: Colors.white,
        fontSize: 16.0,
      );
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
                margin: EdgeInsets.fromLTRB(8, 0, 8, 0),
                child: Align(
                    alignment: Alignment.topLeft,
                    child: Image.asset("images/EduHub.png")),
              ),
              SizedBox(height: 50),
              Container(
                margin: EdgeInsets.fromLTRB(0, 0, 0, 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(
                      fontSize: 14.0,
                      color: Colors.grey,
                    ),
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: Colors.orange.shade700, width: 2.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey, width: 1.0),
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              Container(
                margin: EdgeInsets.fromLTRB(0, 0, 0, 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _passwordController,
                  obscureText: !_passwordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(fontSize: 14, color: Colors.grey),
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: Colors.orange.shade700, width: 2.0),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey, width: 1.0),
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _passwordVisible = !_passwordVisible;
                        });
                      },
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ChangePasswordPage()));
                },
                child: Container(
                  margin: EdgeInsets.fromLTRB(0.5, 0, 0.5, 7),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Text(
                      'Forgot Password?',
                      style: GoogleFonts.getFont(
                        'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.5,
                        color: Colors.orange[900],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                margin: EdgeInsets.fromLTRB(0, 32, 0, 15),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                  ),
                  onPressed: _login,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 12),
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        'Log In',
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
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Don’t have an account? ',
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
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SignUpPage(),
                        ),
                      );
                    },
                    child: Text(
                      ' Sign Up',
                      style: GoogleFonts.getFont(
                        'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.5,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
