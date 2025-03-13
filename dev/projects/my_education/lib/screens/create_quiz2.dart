import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateQuiz2 extends StatefulWidget {
  final String category;
  final String subject;

  CreateQuiz2({required this.category, required this.subject});

  @override
  _CreateQuiz2State createState() => _CreateQuiz2State();
}

class _CreateQuiz2State extends State<CreateQuiz2> {
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _option1Controller = TextEditingController();
  final TextEditingController _option2Controller = TextEditingController();
  final TextEditingController _option3Controller = TextEditingController();
  final TextEditingController _correctAnswerController = TextEditingController();

  int questionNumber = 1;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  User? currentUser;
  String? currentSetPath; // Store the current set path

  @override
  void initState() {
    super.initState();
    // Get current user
    currentUser = FirebaseAuth.instance.currentUser;
    _initializeSet(); // Initialize the set path on startup
  }


Future<void> _saveQuestion() async {
  if (_validateFields()) {
    if (currentUser != null && currentSetPath != null) {
      String userId = currentUser!.uid;

      // 在当前 set 路径下保存问题
      await _databaseRef
          .child('$currentSetPath/Question $questionNumber')
          .set({
        'question': _questionController.text.trim(),
        'option1': _option1Controller.text.trim(),
        'option2': _option2Controller.text.trim(),
        'option3': _option3Controller.text.trim(),
        'correctAnswer': _correctAnswerController.text.trim(),
          // 记录用户 ID
      }).then((_) {
        _clearFields();
        setState(() {
          questionNumber++;
        });
      }).catchError((e) {
        _showToast('Failed to save question: $e');
      });
    } else {
      _showToast('User not logged in or set not initialized.');
    }
  } else {
    _showToast('Please fill in all fields.');
  }
}


Future<String> _findNextAvailableSet() async {
  final baseSubjectPath = 'quiz/${widget.category}/${widget.subject}';
  final DataSnapshot snapshot = await _databaseRef.child(baseSubjectPath).get();

  if (snapshot.exists) {
    // Find the next available set number by checking existing nodes
    int setNumber = 1;
    while (snapshot.child('Set $setNumber').exists) {
      setNumber++;
    }
    // Return the path of the next available set
    return '$baseSubjectPath/Set $setNumber';
  } else {
    // If the directory does not exist, create Set 1
    return '$baseSubjectPath/Set 1';
  }
}

Future<void> _initializeSet() async {
  if (currentUser != null) {
    try {
      // Find the appropriate set path
      final setPath = await _findNextAvailableSet();

      // Create the new set only if it does not exist
      final setSnapshot = await _databaseRef.child(setPath).get();
      if (!setSnapshot.exists) {
        await _databaseRef.child(setPath).set({
          'id': setPath,
          'provider': currentUser!.uid,
          'approve': false,
          // Add other initial data as needed
        });

        setState(() {
          currentSetPath = setPath; // Update the state with the new path
        });
      }
    } catch (e) {
      _showToast('Failed to initialize set: $e');
    }
  }
}


  bool _validateFields() {
    return _questionController.text.trim().isNotEmpty &&
        _option1Controller.text.trim().isNotEmpty &&
        _option2Controller.text.trim().isNotEmpty &&
        _option3Controller.text.trim().isNotEmpty &&
        _correctAnswerController.text.trim().isNotEmpty;
  }

  void _clearFields() {
    _questionController.clear();
    _option1Controller.clear();
    _option2Controller.clear();
    _option3Controller.clear();
    _correctAnswerController.clear();
  }

  void _showConfirmationDialog({required bool isDone}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmation'),
          content: Text('Do you want to save this question?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog without saving
              },
              child: Text('No'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _saveQuestion(); // Save the question
                if (isDone) {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('Submission Successful'),
                        content: Text('Your data will be reviewed by the admin.'),
                        actions: [
                          TextButton(
                            child: Text('OK'),
                            onPressed: () {
                              Navigator.of(context).pop(); // Close the dialog
                              Navigator.of(context).pop(); // Pop the CreateQuiz2 page
                            },
                          ),
                        ],
                      );
                    },
                  );
                }
              },
              child: Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Question $questionNumber',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: Icon(Icons.arrow_back),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                borderRadius:
                    BorderRadius.only(bottomRight: Radius.circular(60)),
              ),
              height: 150,
              child: Padding(
                padding: const EdgeInsets.only(left: 64, right: 64, top: 32),
                child: Center(
                  child: TextField(
                    controller: _questionController,
                    decoration: InputDecoration(
                      labelText: 'Question',
                      labelStyle:
                          TextStyle(fontSize: 14, color: Colors.grey),
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.orange.shade700, width: 2.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey, width: 1.0),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 8.0),
                      fillColor: Colors.white,
                      filled: true,
                    ),
                  ),
                ),
              ),
            ),
            Stack(
              children: [
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    color: Colors.orange.shade700,
                    height: MediaQuery.of(context).size.height / 2,
                    width: MediaQuery.of(context).size.width,
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.only(topLeft: Radius.circular(60)),
                      color: Theme.of(context).scaffoldBackgroundColor,
                    ),
                    height: MediaQuery.of(context).size.height,
                    width: MediaQuery.of(context).size.width,
                    child: Padding(
                      padding: const EdgeInsets.all(64.0),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildTextField(_option1Controller, 'Option 1'),
                            SizedBox(height: 20),
                            _buildTextField(_option2Controller, 'Option 2'),
                            SizedBox(height: 20),
                            _buildTextField(_option3Controller, 'Option 3'),
                            SizedBox(height: 20),
                            _buildTextField(
                                _correctAnswerController, 'Correct Answer'),
                            Container(
                              margin: EdgeInsets.fromLTRB(0, 32, 0, 15),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(5)),
                                ),
                                onPressed: () {
                                  if (_validateFields()) {
                                    _showConfirmationDialog(isDone: true);
                                  } else {
                                    _showToast('Please fill in all fields.');
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      top: 12, bottom: 12),
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Done',
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
                            Container(
                              margin: EdgeInsets.fromLTRB(0, 0, 0, 15),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(5)),
                                ),
                                onPressed: () {
                                  if (_validateFields()) {
                                    _showConfirmationDialog(isDone: false);
                                  } else {
                                    _showToast('Please fill in all fields.');
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      top: 12, bottom: 12),
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Save & Add New Question',
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
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TextField _buildTextField(
      TextEditingController controller, String labelText) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(fontSize: 14, color: Colors.grey),
        border: OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.orange.shade700, width: 2.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey, width: 1.0),
        ),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        fillColor: Colors.white,
        filled: true,
      ),
    );
  }

  void _showToast(String message) {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'OK',
          onPressed: scaffold.hideCurrentSnackBar,
        ),
      ),
    );
  }
}
