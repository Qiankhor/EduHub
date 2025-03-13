import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CreateTeacherPage extends StatefulWidget {
  @override
  _CreateTeacherPageState createState() => _CreateTeacherPageState();
}

class _CreateTeacherPageState extends State<CreateTeacherPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _educationLevelController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _calendarController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  User? currentUser;
  File? _file;
  String _fileName = '';
    File? _imageFile;
  String _imageName = '';
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    currentUser = FirebaseAuth.instance.currentUser;
  }
Widget _buildTextField(TextEditingController controller, String labelText, 
    {bool isMultiline = false, bool isCalendar = false, bool isTime = false, bool isNumber = false}) {
  return Container(
    margin: EdgeInsets.fromLTRB(0, 0, 0, 24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
    ),
    child: TextField(
      controller: controller,
      maxLines: isMultiline ? null : 1, // 允许多行文本输入
      readOnly: isCalendar || isTime, // 选择日期/时间时禁用键盘
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
        suffixIcon: isCalendar
            ? Icon(Icons.calendar_today, color: Colors.orange.shade700)
            : (isTime ? Icon(Icons.access_time, color: Colors.orange.shade700) : null), 
      ),
      keyboardType: isMultiline 
          ? TextInputType.multiline 
          : (isNumber ? TextInputType.number : TextInputType.text), // 如果是 pointsController，键盘类型为数字
      inputFormatters: isNumber 
          ? [FilteringTextInputFormatter.digitsOnly] // 只允许输入数字
          : [],
      onTap: () async {
        if (isCalendar) {
         // 选择日期
            DateTime? pickedDate = await showDatePicker(
              context: context,
              initialDate: DateTime.now(), // 默认选择今天
              firstDate: DateTime(2000), // 允许的最早日期
              lastDate: DateTime.now(), // 禁止选择今天之后的日期
            );


          if (pickedDate != null) {
            String formattedDate = DateFormat('dd MMMM yyyy').format(pickedDate);
            controller.text = formattedDate;
          }
        } 

        if (isTime) {
          // 选择时间
          TimeOfDay? pickedTime = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
          );

          if (pickedTime != null) {
            // 将 TimeOfDay 转换为 DateTime
            DateTime tempDate = DateTime(0, 0, 0, pickedTime.hour, pickedTime.minute);

            // 格式化时间为 8:00pm
            String formattedTime = DateFormat('h:mma').format(tempDate).toLowerCase(); 

            controller.text = formattedTime; 
          }
        }
      },
    ),
  );
}


 Future<void> _pickImage() async {
  try {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _imageName = path.basename(pickedFile.path); // Extract image name
      });
    } else {
      print('No image selected.');
    }
  } catch (e) {
    print('Error picking image: $e');
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
        _fileName = path.basename(result.files.single.path!); 
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
      String filePath = ''; // Initialize filePath for PDF
      String imagePath = ''; // Initialize imagePath for image

      // Upload image file if selected
      if (_imageFile != null) {
        try {
          print('Attempting to upload Image...');
          setState(() {
            _isUploading = true; // Set uploading state to true
          });

          // Show the progress dialog for image upload
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                content: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text('Uploading Image...'),
                  ],
                ),
              );
            },
          );

          // Set the storage reference for the image
          final storageRef = FirebaseStorage.instanceFor(
            bucket: "myeducation-865f1.appspot.com",
          ).ref().child('tutor/images/${DateTime.now().toIso8601String()}');

          final uploadTask = storageRef.putFile(_imageFile!);
          final snapshot = await uploadTask.whenComplete(() {});

          // Get the download URL
          imagePath = await snapshot.ref.getDownloadURL();
          print('Image uploaded successfully: $imagePath');

        } catch (e) {
          print('Failed to upload Image: $e');
          _showToast('Failed to upload Image: $e');
          Navigator.of(context).pop(); // Dismiss the dialog if upload fails
          setState(() {
            _isUploading = false; // Hide progress indicator
          });
          return;
        } finally {
          Navigator.of(context).pop(); // Dismiss the progress dialog
          setState(() {
            _isUploading = false; // Hide progress indicator
          });
        }
      }

      // Upload PDF file if selected
      if (_file != null) {
        try {
          print('Attempting to upload file...');
          setState(() {
            _isUploading = true; // Set uploading state to true
          });

          // Show the progress dialog for file upload
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                content: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text('Uploading File...'),
                  ],
                ),
              );
            },
          );

          // Set the storage reference for the file
          final fileStorageRef = FirebaseStorage.instanceFor(
            bucket: "myeducation-865f1.appspot.com",
          ).ref().child('tutor/files/${capitalizeFirstLetter(_nameController.text.trim())}_${capitalizeFirstLetter(_educationLevelController.text.trim())}.pdf'); // Change extension if needed

          final fileUploadTask = fileStorageRef.putFile(_file!);
          final fileSnapshot = await fileUploadTask.whenComplete(() {});

          // Get the download URL
          filePath = await fileSnapshot.ref.getDownloadURL();
          print('File uploaded successfully: $filePath');

        } catch (e) {
          print('Failed to upload file: $e');
          _showToast('Failed to upload file: $e');
          Navigator.of(context).pop(); // Dismiss the dialog if upload fails
          setState(() {
            _isUploading = false; // Hide progress indicator
          });
          return;
        } finally {
          Navigator.of(context).pop(); // Dismiss the progress dialog
          setState(() {
            _isUploading = false; // Hide progress indicator
          });
        }
      }

      // Save data to the database
      try {
        String key = _databaseRef.push().key!;
        await _databaseRef.child('tutorInfo').child(key).set({
          'approve': false,
          'id': key,
          'name': _nameController.text.trim(),
          'educationLevel': _educationLevelController.text.trim(),
          'year': _yearController.text.trim(),
          'dob' :_calendarController.text.trim(),
          'imagePath': imagePath, 
          'filePath': filePath, 
          'provider': userId,
        });

        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
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

 void _clearFields() {
    _nameController.clear();
    _educationLevelController.clear();
    _yearController.clear();
    _calendarController.clear();
    setState(() {
      _file = null;
      _fileName = '';
      _imageFile = null;
      _imageName = '';
    });
  }

  bool _validateFields() {
    return _nameController.text.trim().isNotEmpty &&
           _educationLevelController.text.trim().isNotEmpty  &&
           _yearController.text.trim().isNotEmpty && _yearController.text.trim().isNotEmpty &&
          _imageFile!=null&& _file!=null;
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Apply Information', style: GoogleFonts.poppins()),
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
              _buildTextField(_nameController, 'Full Name'),
              _buildTextField(_educationLevelController, 'Highest Education Level'),
              _buildTextField(_yearController, 'Year of Experience',isNumber:true),
              _buildTextField(_calendarController, 'Date of Birth',isCalendar: true),

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
      Expanded( // Make the TextButton take up the remaining space
        child: TextButton(
          onPressed: _pickImage,
          child: Text(
            _imageName.isEmpty
                ? 'Upload your resume photo'
                : 'Selected Image: $_imageName',
            overflow: TextOverflow.ellipsis, // Truncate text with ellipsis
            maxLines: 1, // Ensure the text is a single line
          ),
        ),
      ),
    ],
  ),
)
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
      Expanded( // Make the TextButton take up the remaining space
        child: TextButton(
          onPressed: _pickPdf,
          child: Text(
            _fileName.isEmpty
                ? 'Upload your resume in PDF form'
                : 'Selected File: $_fileName',
            overflow: TextOverflow.ellipsis, // Truncate text with ellipsis
            maxLines: 1, // Ensure the text is a single line
          ),
        ),
      ),
    ],
  ),
)
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
}
