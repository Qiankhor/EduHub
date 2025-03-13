import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';

class EditFieldScreen extends StatelessWidget {
  final String field;
  final String currentValue;

  const EditFieldScreen({
    super.key,
    required this.field,
    required this.currentValue,
  });

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  bool _isValidPhoneNumber(String phoneNumber) {
    final phoneRegex = RegExp(r'^\d{2}\d{7,8}$');
    return phoneRegex.hasMatch(phoneNumber);
  }

  // Map display names to Firestore field names
  String getFirestoreFieldName() {
    switch (field) {
      case 'Email':
        return 'email';
      case 'Phone Number':
        return 'phone';
      case 'Username':
        return 'username';
      default:
        return field;
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController controller =
        TextEditingController(text: currentValue);

    return Scaffold(
      appBar: AppBar(title: Text('Edit $field')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(labelText: field),
              keyboardType: field == 'Email'
                  ? TextInputType.emailAddress
                  : field == 'Phone Number'
                      ? TextInputType.phone
                      : TextInputType.text,
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: () async {
                  String newValue = controller.text.trim();
                  if (newValue.isEmpty) {
                    Fluttertoast.showToast(
                      msg: "$field cannot be empty",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                    );
                    return;
                  }

                  // Validate email format if editing email
                  if (field == 'Email' && !_isValidEmail(newValue)) {
                    Fluttertoast.showToast(
                      msg: "Please enter a valid email address",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                      backgroundColor: Colors.red,
                    );
                    return;
                  }

                  // Validate phone number format if editing phone number
                  if (field == 'Phone Number' &&
                      !_isValidPhoneNumber(newValue)) {
                    Fluttertoast.showToast(
                      msg: "Please enter a valid phone number (9-10 digits)",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                      backgroundColor: Colors.red,
                    );
                    return;
                  }

                  try {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      // Use the correct Firestore field name
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .update({getFirestoreFieldName(): newValue});

                      Fluttertoast.showToast(
                        msg: "$field updated successfully",
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM,
                        backgroundColor: Colors.green,
                      );
                      Navigator.pop(context);
                    } else {
                      print("User not logged in");
                    }
                  } catch (e) {
                    print("Error updating $field: $e");
                    Fluttertoast.showToast(
                      msg: "Failed to update $field",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
