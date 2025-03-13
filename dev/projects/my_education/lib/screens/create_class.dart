import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RegisterClassPage extends StatefulWidget {
  @override
  _RegisterClassPageState createState() => _RegisterClassPageState();
}

class _RegisterClassPageState extends State<RegisterClassPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();
  final TextEditingController _calendarController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  
  String? _profilePicUrl;

  User? currentUser;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    currentUser = FirebaseAuth.instance.currentUser;
    _fetchUserData();
  }
  Future<void> _fetchUserData() async {
  try {
    // 获取当前用户
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // 从Firestore中获取用户数据
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        // 确保小部件仍然挂载
        if (mounted) {
          setState(() {
            _profilePicUrl = userDoc.data().toString().contains('profilePic')
                ? userDoc['profilePic']
                : null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _profilePicUrl = null;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _profilePicUrl = null;
        });
      }
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _profilePicUrl = null;
      });
    }
    print('Error fetching user data: $e');
  }
}

Widget _buildTextField(TextEditingController controller, String labelText, 
    {bool isMultiline = false, bool isCalendar = false, bool isTime = false, bool isPoints = false}) {
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
          : (isPoints ? TextInputType.number : TextInputType.text), // 如果是 pointsController，键盘类型为数字
      inputFormatters: isPoints 
          ? [FilteringTextInputFormatter.digitsOnly] // 只允许输入数字
          : [],
      onTap: () async {
        if (isCalendar) {
          // 选择日期
          DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime.now(), // 禁止选择今天之前的日期
            lastDate: DateTime(2100), // 允许未来的日期
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

void _saveEvent() async {
  if (_validateFields()) {
    if (currentUser != null) {
      String userId = currentUser!.uid;
      // Save data to the database
      try {
        String key = _databaseRef.push().key!;
        await _databaseRef.child('class').child(key).set({
          'approve': false,
          'id': key,
          'name': _nameController.text.trim(),
          'startTime': _startTimeController.text.trim(),
          'endTime': _endTimeController.text.trim(),
          'date' :_calendarController.text.trim(),
          'description' : _descriptionController.text.trim(),
          'point': int.tryParse(_pointsController.text.trim()) ?? 0,
          'imagePath': _profilePicUrl,
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
    _startTimeController.clear();
    _endTimeController.clear();
    _calendarController.clear();
    _pointsController.clear();
    _descriptionController.clear();
  }

  bool _validateFields() {
    return _nameController.text.trim().isNotEmpty &&
           _startTimeController.text.trim().isNotEmpty &&_calendarController.text.trim().isNotEmpty &&
           _pointsController.text.trim().isNotEmpty &&_endTimeController.text.trim().isNotEmpty &&
           _descriptionController.text.trim().isNotEmpty;
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
        title: Text('Register Class', style: GoogleFonts.poppins()),
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
              _buildTextField(_nameController, 'Class Name'),
              _buildTextField(_calendarController, 'Date',isCalendar: true),
              _buildTextField(_startTimeController, 'Start Time',isTime: true),
              _buildTextField(_endTimeController, 'End Time',isTime: true),
              _buildTextField(_descriptionController, 'Description', isMultiline: true),
              _buildTextField(_pointsController, 'Points requested per person',isPoints: true),

              
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
