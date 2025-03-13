import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

class PromotionalPage extends StatefulWidget {
  @override
  _PromotionalPageState createState() => _PromotionalPageState();
}

class _PromotionalPageState extends State<PromotionalPage> {
  final TextEditingController _eventNameController = TextEditingController();
  final TextEditingController _targetAudienceController = TextEditingController();
  final TextEditingController _participationFeeController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  User? currentUser;
  File? _imageFile;
  String _imageName = '';
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    currentUser = FirebaseAuth.instance.currentUser;
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

void _saveEvent() async {
  if (_validateFields()) {
    bool hasEnoughPoints = await _checkUserPoints(100);

    if (hasEnoughPoints) {
      bool confirmed = await _showConfirmationDialog(); // 弹出确认对话框

      if (confirmed && currentUser != null) {
      String userId = currentUser!.uid;
      String imagePath = '';

      if (_imageFile != null) {
        try {
          print('Attempting to upload image...');
          
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

          // Use instanceFor with the specific bucket
          final storageRef = FirebaseStorage.instanceFor(
            bucket: "myeducation-865f1.appspot.com"
          ).ref().child('event_images/${DateTime.now().toIso8601String()}');
          
          // Upload the file
          final uploadTask = storageRef.putFile(_imageFile!);
          final snapshot = await uploadTask.whenComplete(() {});

          // Get the download URL
          imagePath = await snapshot.ref.getDownloadURL();
          print('Image uploaded successfully: $imagePath');

        } catch (e) {
          print('Failed to upload image: $e');
          _showToast('Failed to upload image: $e');
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
  // Generate a unique key for the new promotional event
  String key = _databaseRef.child('promotionalEvent').push().key!;
   await _deductPoints(userId, 100);
  // Use the same key for both the push and the set operations
  await _databaseRef.child('promotionalEvent').child(key).set({
    'id': key,
    'approve': false,
    'eventName': _eventNameController.text.trim(),
    'targetAudience': _targetAudienceController.text.trim(),
    'participationFee': _participationFeeController.text.trim(),
    'URL': _urlController.text.trim(),
    'imagePath': imagePath,
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
    }  else {
      _showInsufficientPointsDialog(); // 弹出积分不足提示
    }
  } else {
    _showToast('Please fill in all fields.');
  }
  }
}
Future<bool> _checkUserPoints(int requiredPoints) async {
  String userId = currentUser!.uid;
  DocumentSnapshot snapshot = await FirebaseFirestore.instance.collection('users').doc(userId).get();

  if (snapshot.exists) {
    int currentPoints = snapshot['points'] ?? 0;
    return currentPoints >= requiredPoints;
  }
  return false;
}

// 扣除用户积分
Future<void> _deductPoints(String userId, int points) async {
  DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(userId);

  await FirebaseFirestore.instance.runTransaction((transaction) async {
    DocumentSnapshot snapshot = await transaction.get(userRef);

    if (snapshot.exists) {
      int currentPoints = snapshot['points'] ?? 0;
      transaction.update(userRef, {'points': currentPoints - points});
    }
  });
}

// 显示积分不足提示对话框
void _showInsufficientPointsDialog() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Insufficient Points'),
        content: Text('You do not have enough points to submit.'),
        actions: [
          TextButton(
            child: Text('OK'),
            onPressed: () {
              Navigator.of(context).pop(); // 关闭提示框
            },
          ),
        ],
      );
    },
  );
}

// 显示扣分确认对话框
Future<bool> _showConfirmationDialog() async {
  return await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Confirm Submission'),
        content: Text('Submitting this will deduct 50 points. Do you want to continue?'),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop(false); // 返回 false
            },
          ),
          TextButton(
            child: Text('Confirm'),
            onPressed: () {
              Navigator.of(context).pop(true); // 返回 true
            },
          ),
        ],
      );
    },
  ) ?? false;
}

  void _clearFields() {
    _eventNameController.clear();
    _targetAudienceController.clear();
    _participationFeeController.clear();
    _urlController.clear();
    setState(() {
      _imageFile = null;
       _imageName = '';
    });
  }

  bool _validateFields() {
    return _eventNameController.text.trim().isNotEmpty &&
           _targetAudienceController.text.trim().isNotEmpty &&
           _participationFeeController.text.trim().isNotEmpty &&
           _urlController.text.trim().isNotEmpty && _imageFile!=null;
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
        title: Text('Promotional Event', style: GoogleFonts.poppins()),
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 94, 17, 70),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              _buildTextField(_eventNameController, 'Event Name'),
              _buildTextField(_targetAudienceController, 'Target Audience'),
              _buildTextField(_participationFeeController, 'Participation Fee'),
              _buildTextField(_urlController, 'Activity Details (URL)'),
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
                ? 'Upload your event poster'
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

  Widget _buildTextField(TextEditingController controller, String labelText) {
    return Container(
      margin: EdgeInsets.fromLTRB(0, 0, 0, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
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
        keyboardType: TextInputType.text,
      ),
      
    );
    
  }
}
