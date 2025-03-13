import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

class PastYearPage extends StatefulWidget {
  @override
  _PastYearPageState createState() => _PastYearPageState();
}

class _PastYearPageState extends State<PastYearPage> {
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final DatabaseReference _pastyearRef = FirebaseDatabase.instance.ref().child('pastYear');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  String? _selectedCategory;
  String? _selectedSubject;
  String? _selectedYear;
  List<String> _categories = [];
  List<String> _subjects = [];
  List<String> _years = [];
  bool _isOtherCategorySelected = false;
  bool _isOtherSubjectSelected = false;
  bool _isOtherYearSelected = false;
  User? currentUser;
  File? _file;
  String _fileName = '';
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    currentUser = FirebaseAuth.instance.currentUser;
    _fetchPastYearData();
  }

 Future<void> _fetchPastYearData() async {
  try {
    DataSnapshot snapshot = await _pastyearRef.get();

    if (snapshot.exists) {
      Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;

      Set<String> fetchedCategories = {};
      Set<String> fetchedSubjects = {};
      Set<String> fetchedYears = {};

      // Iterate over each entry in the 'pastYear' node
      for (var entry in data.entries) {
        Map<dynamic, dynamic> entryData = entry.value as Map<dynamic, dynamic>;

        // Extract fields from each entry
        if (entryData.containsKey('category')) {
          fetchedCategories.add(entryData['category']);
        }

        if (entryData.containsKey('subject')) {
          fetchedSubjects.add(entryData['subject']);
        }

        if (entryData.containsKey('year')) {
          fetchedYears.add(entryData['year']);
        }
      }

      // Convert sets to lists
      setState(() {
        _categories = List.from(fetchedCategories);
        _subjects = List.from(fetchedSubjects);
        _years = List.from(fetchedYears);
      });
    } else {
      print('No data found.');
    }

    // Always add "Other" option
    setState(() {
      _categories.add('Other');
      _subjects.add('Other');
      _years.add('Other');
    });

  } catch (e) {
    print('Error fetching data: $e');
  }
}


  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _file = File(result.files.single.path!);
        _fileName = path.basename(result.files.single.path!); // Extract PDF name
      });
    }
  }

    String capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  void _saveEvent() async {
  if (_validateFields()) {
    if (currentUser != null) {
      String userId = currentUser!.uid;
      String filePath = '';

      if (_file != null) {
        try {
          print('Attempting to upload File...');
          
          setState(() {
            _isUploading = true; // Set uploading state to true
          });

          // Show the progress dialog
          showDialog(
            context: context,
            barrierDismissible: false, // Prevent dismissing the dialog by tapping outside
            builder: (BuildContext context) {
              return AlertDialog(
                content: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text('Uploading...'),
                  ],
                ),
              );
            },
          );

          final storageRef = FirebaseStorage.instanceFor(
            bucket: "myeducation-865f1.appspot.com"
          ).ref().child(
            'past_year_question/${capitalizeFirstLetter(_getCategoryValue())}_${capitalizeFirstLetter(_getSubjectValue())}_${capitalizeFirstLetter(_getYearValue())}'
          );
          
          final uploadTask = storageRef.putFile(_file!);
          final snapshot = await uploadTask.whenComplete(() {});

          // Get the download URL
          filePath = await snapshot.ref.getDownloadURL();
          print('File uploaded successfully: $filePath');

        } catch (e) {
          print('Failed to upload File: $e');
          _showToast('Failed to upload File: $e');
          Navigator.of(context).pop(); // Dismiss the dialog if upload fails
          setState(() {
            _isUploading = false; // Hide progress indicator
          });
          return;
        } finally {
          // Ensure the dialog is dismissed in both success and failure scenarios
          Navigator.of(context).pop(); // Dismiss the progress dialog
          setState(() {
            _isUploading = false; // Hide progress indicator
          });
        }
      }

      try {
        String key = _databaseRef.push().key!;
        await _databaseRef.child('pastYear').child(key).set({
          'approve': false,
          'id': key,
          'category': capitalizeFirstLetter(_getCategoryValue()),
          'subject': capitalizeFirstLetter(_getSubjectValue()),
          'year': capitalizeFirstLetter(_getYearValue()),
          'filePath': filePath,
          'provider': userId,
        });

        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false, // Prevent dismissing the dialog by tapping outside
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Submission Successful'),
              content: Text('Your data will be reviewed by the admin.'),
              actions: [
                TextButton(
                  child: Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the success dialog
                    _clearFields(); // Clear fields after closing the dialog
                  },
                ),
              ],
            );
          },
        );
      } catch (e) {
        print('Failed to save event: $e');
        _showToast('Failed to save event: $e');
      }
    } else {
      _showToast('User not logged in or set not initialized.');
    }
  } else {
    _showToast('Please fill in all fields.');
  }
}

// Helper methods to get category, subject, and year values based on selection
String _getCategoryValue() {
  return _selectedCategory == 'Other' ? _categoryController.text.trim() : _selectedCategory ?? '';
}

String _getSubjectValue() {
  return _selectedSubject == 'Other' ? _subjectController.text.trim() : _selectedSubject ?? '';
}

String _getYearValue() {
  return _selectedYear == 'Other' ? _yearController.text.trim() : _selectedYear ?? '';
}



  void _clearFields() {
    _categoryController.clear();
    _subjectController.clear();
    _yearController.clear();
    setState(() {
      _file = null;
      _fileName = '';
    });
  }

  bool _validateFields() {
  // Check if a valid category is selected or "Other" has text
  bool isCategoryValid = _selectedCategory != null &&
      (_selectedCategory != 'Other' || _categoryController.text.trim().isNotEmpty);

  // Check if a valid subject is selected or "Other" has text
  bool isSubjectValid = _selectedSubject != null &&
      (_selectedSubject != 'Other' || _subjectController.text.trim().isNotEmpty);

  // Check if a valid year is selected or "Other" has text
  bool isYearValid = _selectedYear != null &&
      (_selectedYear != 'Other' || _yearController.text.trim().isNotEmpty);

  // Ensure a file is selected
  bool isFileSelected = _file != null;

  return isCategoryValid && isSubjectValid && isYearValid && isFileSelected;
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

  Widget _buildDropdownOrTextField({
    required List<String> items,
    required String? selectedValue,
    required bool isOtherSelected,
    required ValueChanged<String?> onChanged,
    required TextEditingController controller,
    required String labelText,
    required Function fetchData,
  }) {
    return Container(
      margin: EdgeInsets.fromLTRB(0, 0, 0, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: isOtherSelected
        ? TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: labelText,
              labelStyle: TextStyle(
                fontSize: 14.0,
                color: Colors.grey,
              ),
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.orange.shade700, width: 2.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey, width: 1.0),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            ),
          )
        : DropdownButtonFormField<String>(
            value: selectedValue,
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                onChanged(value);
                if (value == 'Other') {
                  fetchData();
                }
              });
            },
            decoration: InputDecoration(
              labelText: labelText,
              border: OutlineInputBorder(),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Past Year Question', style: GoogleFonts.poppins()),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back),
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 94, 17, 70),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDropdownOrTextField(
                items: _categories,
                selectedValue: _selectedCategory,
                isOtherSelected: _isOtherCategorySelected,
                onChanged: (value) {
                  _selectedCategory = value;
                  _isOtherCategorySelected = value == 'Other';
                },
                controller: _categoryController,
                labelText: 'Category (SPM/STPM)',
                fetchData: () {
                  // Fetch subjects or handle additional logic here
                },
              ),
              _buildDropdownOrTextField(
                items: _subjects,
                selectedValue: _selectedSubject,
                isOtherSelected: _isOtherSubjectSelected,
                onChanged: (value) {
                  _selectedSubject = value;
                  _isOtherSubjectSelected = value == 'Other';
                },
                controller: _subjectController,
                labelText: 'Subject',
                fetchData: () {
                  // Fetch years or handle additional logic here
                },
              ),
              _buildDropdownOrTextField(
                items: _years,
                selectedValue: _selectedYear,
                isOtherSelected: _isOtherYearSelected,
                onChanged: (value) {
                  _selectedYear = value;
                  _isOtherYearSelected = value == 'Other';
                },
                controller: _yearController,
                labelText: 'Year',
                fetchData: () {
                  // Additional logic here if needed
                },
              ),
              Container(
                margin: EdgeInsets.fromLTRB(0, 0, 0, 35),
                decoration: BoxDecoration(
                  border: Border.all(color: Color(0xFF535CE8)),
                  borderRadius: BorderRadius.circular(8),
                  color: Color(0x80F1F2FD),
                ),
                child: Container(
                  padding: EdgeInsets.fromLTRB(0, 7, 0, 7),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: SvgPicture.asset('vectors/cloud_upload_1_x2.svg'),
                      ),
                      SizedBox(width: 8), // Add some spacing between the icon and text
                      Expanded(
                        child: TextButton(
                          onPressed: _pickPdf,
                          child: Text(
                            _fileName.isEmpty
                                ? 'Upload in PDF form'
                                : 'Selected File: $_fileName',
                            overflow: TextOverflow.ellipsis, // Truncate text with ellipsis
                            maxLines: 1, // Ensure the text is a single line
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                margin: EdgeInsets.fromLTRB(0, 32, 0, 15),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                  ),
                  onPressed: _saveEvent,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 12),
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        'Submit',
                        style: GoogleFonts.poppins(
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
}