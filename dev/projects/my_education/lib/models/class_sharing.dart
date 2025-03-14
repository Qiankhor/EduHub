import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_education/models/Teacher_details_page.dart';

class SharingClassDetailPage extends StatefulWidget {
  final Map<String, dynamic> data;

  SharingClassDetailPage({required this.data});

  @override
  _SharingClassPageState createState() => _SharingClassPageState();
}

class _SharingClassPageState extends State<SharingClassDetailPage> {
  late String _providerId = widget.data['provider'];
  User? currentUser;
  late String userId;
  late Future<String> providerName;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    providerName = _getProviderName(_providerId);
    currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      userId = currentUser!.uid;
    }
  }

  Future<String> _getProviderName(String providerId) async {
    try {
      DocumentSnapshot providerSnapshot =
          await _firestore.collection('users').doc(providerId).get();
      if (providerSnapshot.exists) {
        Map<String, dynamic>? providerData =
            providerSnapshot.data() as Map<String, dynamic>?;
        return providerData?['fullName'] ?? 'Unknown';
      } else {
        return 'Unknown';
      }
    } catch (e) {
      print('Error fetching provider name: $e');
      return 'Unknown';
    }
  }

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
    DocumentReference providerRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.data['provider']);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userRef);
      DocumentSnapshot snapshot2 = await transaction.get(providerRef);

      if (snapshot.exists && snapshot2.exists) {
        int currentUserPoints = snapshot['points'] ?? 0;
        transaction.update(userRef, {'points': currentUserPoints - points});
        int tutorPoints = snapshot2['points'] ?? 0;
        transaction.update(providerRef, {'points': tutorPoints + points});
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
              content: Text(
                  'Submitting this will deduct ${widget.data['point']} points. Do you want to continue?'),
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

  void _saveBooking() async {
    bool hasEnoughPoints = await _checkUserPoints(widget.data['point']);
    if (hasEnoughPoints) {
      bool confirmed = await _showConfirmationDialog(); // 弹出确认对话框

      if (confirmed && currentUser != null) {
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
                  Text('Processing...'),
                ],
              ),
            );
          },
        );

        try {
          String userId = currentUser!.uid;
          await _deductPoints(userId, widget.data['point']);
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
            'bookedSessions': FieldValue.arrayUnion([widget.data['id']])
          });

          String sessionType = widget.data['type'] ??
              'sharing'; // Default to 'sharing' if not specified

          // Construct the correct path
          String dbPath =
              '$sessionType/${widget.data['id']}/joinedParticipants';

          // Get a reference to the joinedParticipants counter with the correct path
          DatabaseReference sessionRef = FirebaseDatabase.instance.ref(dbPath);

          try {
            // Get the current value
            DataSnapshot snapshot = await sessionRef.get();
            int currentCount = 0;

            // If there's an existing value, use it
            if (snapshot.exists) {
              currentCount = (snapshot.value as int?) ?? 0;
            }

            // Set the new value (current + 1)
            await sessionRef.set(currentCount + 1);
          } catch (e) {
            print('Error updating participant count: $e');
            // Consider showing an error message to the user
          }

          Navigator.of(context).pop(); // 关闭上传弹窗

          setState(() {});

          // 显示提交成功的提示框
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Join Successful'),
                content: Text(
                    'You have successfully joined. You can check the schedule for more details.'),
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
        }
      }
    } else {
      _showInsufficientPointsDialog(); // 弹出积分不足提示
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            widget.data['imagePath'] != null
                ? Image.network(
                    widget.data['imagePath'],
                    fit: BoxFit.contain,
                    width: double.infinity,
                  )
                : Container(height: 200, color: Colors.grey),
            Padding(
              padding:
                  const EdgeInsets.only(right: 16, left: 16, top: 8, bottom: 8),
              child: Text(
                widget.data['name'] ?? 'Unknown Name',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16, left: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.person_outlined),
                      SizedBox(width: 10),
                      FutureBuilder<String>(
                        future: providerName,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Text('Loading...',
                                style: TextStyle(color: Colors.grey));
                          } else if (snapshot.hasError) {
                            return Text('Error',
                                style: TextStyle(color: Colors.red));
                          } else {
                            return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              TeacherDetailPage(
                                                  teacherData: widget.data)));
                                },
                                child: Text(snapshot.data ?? 'Unknown',
                                    style: TextStyle(
                                        color: Colors.blueAccent,
                                        fontWeight: FontWeight.bold)));
                          }
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.calendar_today),
                      SizedBox(
                        width: 10,
                      ),
                      Text(
                        '${widget.data['date'] ?? 'Unknown'}',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.access_time),
                      SizedBox(
                        width: 10,
                      ),
                      Text(
                        '${widget.data['startTime']} - ${widget.data['endTime']}',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Divider(
                    color: Colors.grey, // 线的颜色
                    thickness: 1, // 线的厚度
                    indent: 5, // 左边间距
                    endIndent: 5, // 右边间距
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Description'),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${widget.data['description'] ?? 'Unknown'}',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  SizedBox(
                    height: 80,
                  )
                ],
              ),
            ),
            Container(
                padding: EdgeInsets.all(25),
                margin: EdgeInsets.fromLTRB(0, 32, 0, 15),
                child: userId != widget.data['provider']
                    ? FutureBuilder<bool>(
                        future: _checkIfAlreadyJoined(),
                        builder: (context, snapshot) {
                          bool alreadyJoined = snapshot.data ?? false;

                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  alreadyJoined ? Colors.grey : Colors.green,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5)),
                            ),
                            onPressed: alreadyJoined
                                ? null
                                : () {
                                    _saveBooking();
                                  },
                            child: Padding(
                              padding:
                                  const EdgeInsets.only(top: 12, bottom: 12),
                              child: Align(
                                alignment: Alignment.center,
                                child: Text(
                                  alreadyJoined
                                      ? "Already Joined (${(widget.data['point'] == 0) ? 'Free' : '${widget.data['point']} points'})"
                                      : "Join (${widget.data['point']} points)",
                                  style: GoogleFonts.getFont(
                                    'Poppins',
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                    height: 1.4,
                                    color: alreadyJoined
                                        ? const Color.fromARGB(
                                            179, 130, 129, 129)
                                        : Color(0xFFFFFFFF),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    : null),
          ],
        ),
      ),
    );
  }

  Future<bool> _checkIfAlreadyJoined() async {
    if (currentUser == null) return false;

    try {
      // Check Firestore for this user's booked sessions
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      if (userDoc.exists) {
        // Get the user's booked sessions
        List<dynamic> bookedSessions = userDoc.get('bookedSessions') ?? [];

        // Check if this session's ID is in the list
        return bookedSessions.contains(widget.data['id']);
      }
      return false;
    } catch (e) {
      print('Error checking joined status: $e');
      return false;
    }
  }
}
