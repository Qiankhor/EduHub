import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateSurveyPage extends StatefulWidget {
  CreateSurveyPage();

  @override
  _CreateSurveyPageState createState() => _CreateSurveyPageState();
}

class _CreateSurveyPageState extends State<CreateSurveyPage> {
  final TextEditingController _surveyThemeController = TextEditingController();
  final TextEditingController _targetAudienceController =
      TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  bool _isUploading = false;
  User? currentUser;
  @override
  void initState() {
    super.initState();
    // Get current user
    currentUser = FirebaseAuth.instance.currentUser;
  }

  void _saveSurvey() async {
    if (_validateFields()) {
      bool hasEnoughPoints = await _checkUserPoints(50);

      if (hasEnoughPoints) {
        bool confirmed = await _showConfirmationDialog(); // 弹出确认对话框

        if (confirmed && currentUser != null) {
          setState(() {
            _isUploading = true; // 设置上传状态为 true
          });

          // 显示上传中的弹窗
          showDialog(
            context: context,
            barrierDismissible: false, // 禁止点击外部关闭弹窗
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

          try {
            String userId = currentUser!.uid;
            String key = _databaseRef.push().key!;

            // 扣除用户 5 分
            await _deductPoints(userId, 50);

            await _databaseRef.child('survey').child(key).set({
              'id': key,
              'surveyTheme': _surveyThemeController.text.trim(),
              'targetAudience': _targetAudienceController.text.trim(),
              'URL': _urlController.text.trim(),
              'provider': userId,
              'approve': false,
            });

            Navigator.of(context).pop(); // 关闭上传弹窗
            _clearFields(); // 清空输入字段

            // 显示提交成功的提示框
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
                        Navigator.of(context).pop(); // 关闭成功提示框
                      },
                    ),
                  ],
                );
              },
            );
          } catch (e) {
            Navigator.of(context).pop(); // 关闭上传弹窗
            _showToast('Failed to save question: $e');
          } finally {
            setState(() {
              _isUploading = false; // 上传结束后更新状态
            });
          }
        }
      } else {
        _showInsufficientPointsDialog(); // 弹出积分不足提示
      }
    } else {
      _showToast('Please fill in all fields.');
    }
  }

// 检查用户积分是否足够
  Future<bool> _checkUserPoints(int requiredPoints) async {
    String userId = currentUser!.uid;
    DocumentSnapshot snapshot =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (snapshot.exists) {
      int currentPoints = snapshot['points'] ?? 0;
      return currentPoints >= requiredPoints;
    }
    return false;
  }

// 扣除用户积分
  Future<void> _deductPoints(String userId, int points) async {
    DocumentReference userRef =
        FirebaseFirestore.instance.collection('users').doc(userId);
    CollectionReference transactionRef = userRef.collection('transactions');

// Perform transaction to update points and save history
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userRef);
      int currentPoints = 0;
      if (snapshot.exists) {
        currentPoints = snapshot['points'] ?? 0;
        transaction.update(userRef, {'points': currentPoints - points});
      } else {
        transaction.set(userRef, {'points': -50});
      }

      // Create a document reference for the new transaction record
      DocumentReference newTransactionRef =
          transactionRef.doc(); // Generate a new document ID

      // Add the transaction record as part of the transaction
      transaction.set(newTransactionRef, {
        'points': 50,
        'type': 'deduction', // or 'deduction' for deductions
        'reason': 'Distribute survey',
        'timestamp': FieldValue.serverTimestamp(),
      });
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
              content: Text(
                  'Submitting this will deduct 50 points. Do you want to continue?'),
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
        ) ??
        false;
  }

  void _clearFields() {
    _surveyThemeController.clear();
    _targetAudienceController.clear();
    _urlController.clear();
  }

  bool _validateFields() {
    return _surveyThemeController.text.trim().isNotEmpty &&
        _targetAudienceController.text.trim().isNotEmpty &&
        _urlController.text.trim().isNotEmpty;
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Distribute Survey',
          style: GoogleFonts.poppins(),
        ),
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
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
              Container(
                margin: EdgeInsets.fromLTRB(0, 0, 0, 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _surveyThemeController,
                  decoration: InputDecoration(
                    labelText: 'Survey Theme',
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
                  keyboardType: TextInputType.text,
                ),
              ),
              Container(
                margin: EdgeInsets.fromLTRB(0, 0, 0, 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _targetAudienceController,
                  decoration: InputDecoration(
                    labelText: 'Target Audience',
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
                  keyboardType: TextInputType.text,
                ),
              ),
              Container(
                margin: EdgeInsets.fromLTRB(0, 0, 0, 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    labelText: 'Survey URL',
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
                  ),
                ),
              ),
              Container(
                margin: EdgeInsets.fromLTRB(0, 32, 0, 15),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                  ),
                  onPressed: () {
                    _saveSurvey();
                    setState(() {});
                  },
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
}
