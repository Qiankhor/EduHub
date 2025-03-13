import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_education/screens/create_quiz2.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateQuiz1 extends StatefulWidget {
  @override
  _CreateQuiz1State createState() => _CreateQuiz1State();
}

class _CreateQuiz1State extends State<CreateQuiz1> {
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  String? _selectedCategory;
  String? _selectedSubject;
  bool _isOtherSelected = false;
  bool _isOtherSubjectSelected = false;
  List<String> _categories = [];
  List<String> _subjects = [];
  DatabaseReference _quizRef = FirebaseDatabase.instance.ref().child('quiz');
  FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _fetchQuizData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Create Quiz', style: GoogleFonts.poppins()),
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: Icon(
            Icons.arrow_back,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 94, 17, 70),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: EdgeInsets.fromLTRB(0, 0, 0, 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isOtherSelected
                    ? TextField(
                        controller: _categoryController,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          labelStyle: TextStyle(
                            fontSize: 14.0,
                            color: Colors.grey,
                          ),
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Colors.orange.shade700, width: 2.0),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.grey, width: 1.0),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12.0, vertical: 8.0),
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        items: _categories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList()
                          ..add(
                            DropdownMenuItem(
                              value: 'Other',
                              child: Text('Other'),
                            ),
                          ),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value;
                            _isOtherSelected = value == 'Other';
                            _fetchSubjects(value);
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                      ),
              ),
              Container(
                margin: EdgeInsets.fromLTRB(0, 0, 0, 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isOtherSubjectSelected
                    ? TextField(
                        controller: _subjectController,
                        decoration: InputDecoration(
                          labelText: 'Subject',
                          labelStyle: TextStyle(
                            fontSize: 14.0,
                            color: Colors.grey,
                          ),
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Colors.orange.shade700, width: 2.0),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.grey, width: 1.0),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12.0, vertical: 8.0),
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        value: _selectedSubject,
                        items: _subjects.map((String subject) {
                          return DropdownMenuItem<String>(
                            value: subject,
                            child: Text(subject),
                          );
                        }).toList()
                          ..add(
                            DropdownMenuItem(
                              value: 'Other',
                              child: Text('Other'),
                            ),
                          ),
                        onChanged: (value) {
                          setState(() {
                            _selectedSubject = value;
                            _isOtherSubjectSelected = value == 'Other';
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Subject',
                          border: OutlineInputBorder(),
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
                  onPressed: _nextPage,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 12),
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        'Create',
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
    );
  }

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

  String capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  void _nextPage() {
    String category = _isOtherSelected
        ? capitalizeFirstLetter(_categoryController.text.trim())
        : _selectedCategory ?? '';

    String subject = _isOtherSubjectSelected
        ? capitalizeFirstLetter(_subjectController.text.trim())
        : _selectedSubject ?? '';

    if (category.isEmpty || subject.isEmpty) {
      _showToast('Please fill in all fields.');
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CreateQuiz2(
            category: category,
            subject: subject,
          ),
        ),
      );
    }
  }

  Future<void> _fetchQuizData() async {
    try {
      DataSnapshot categoriesSnapshot = await _quizRef.get();

      if (categoriesSnapshot.exists) {
        Map<dynamic, dynamic> categoriesData =
            categoriesSnapshot.value as Map<dynamic, dynamic>;

        List<String> fetchedCategories = [];

        for (var categoryEntry in categoriesData.entries) {
          String categoryName = categoryEntry.key;
          fetchedCategories.add(categoryName);
        }

        setState(() {
          _categories = fetchedCategories;
        });
      } else {
        print('No categories found.');
      }
    } catch (e) {
      print('Error fetching quiz data: $e');
    }
  }

  Future<void> _fetchSubjects(String? category) async {
    if (category == null) {
      return;
    }

    try {
      DataSnapshot subjectsSnapshot = await _quizRef.child(category).get();

      if (subjectsSnapshot.exists) {
        Map<dynamic, dynamic> subjectsData =
            subjectsSnapshot.value as Map<dynamic, dynamic>;

        List<String> fetchedSubjects = [];

        for (var subjectEntry in subjectsData.entries) {
          String subjectName = subjectEntry.key;
          fetchedSubjects.add(subjectName);
        }

        setState(() {
          _subjects = fetchedSubjects;
          _selectedSubject = _subjects.isNotEmpty ? _subjects[0] : null;
        });
      } else {
        print('No subjects found for category $category.');
      }
    } catch (e) {
      print('Error fetching subjects: $e');
    }
  }
}
