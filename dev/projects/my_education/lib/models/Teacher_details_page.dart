import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_education/models/class_sharing.dart';

class TeacherDetailPage extends StatefulWidget {
  final Map<String, dynamic> teacherData;

  TeacherDetailPage({required this.teacherData});

  @override
  _TeacherDetailPageState createState() => _TeacherDetailPageState();
}

class _TeacherDetailPageState extends State<TeacherDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<String> userBookedSessions = []; // To store the user's booked sessions
  final DatabaseReference _classRef =
      FirebaseDatabase.instance.ref().child('class');
  final DatabaseReference _sharingRef =
      FirebaseDatabase.instance.ref().child('sharing');
  List<Map<String, dynamic>> upcomingBookings = [];
  List<Map<String, dynamic>> pastBookings = [];
  bool _isLoading = true; // Track loading state
  late Future<String> _providerNameFuture;
  late Future<String> _providerProfileFuture;
  String _fullName = '';
  String _email = '';
  String? _profilePicUrl;
  User? currentUser;

  @override
  void initState() {
    super.initState();
    currentUser = FirebaseAuth.instance.currentUser;
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
    _fetchTeacherData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchTeacherData() async {
    try {
      // 从Firestore中获取用户数据
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.teacherData['provider'])
          .get();

      if (userDoc.exists) {
        // 确保小部件仍然挂载
        if (mounted) {
          setState(() {
            _fullName = userDoc.data().toString().contains('fullName')
                ? userDoc['fullName']
                : 'No Name';
            _email = userDoc.data().toString().contains('email')
                ? userDoc['email']
                : 'No Email';
            _profilePicUrl = userDoc.data().toString().contains('profilePic')
                ? userDoc['profilePic']
                : null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _fullName = 'User not found';
            _email = 'Email not found';
            _profilePicUrl = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _fullName = 'Error fetching teacher data';
          _email = 'Error fetching teacher data';
          _profilePicUrl = null;
        });
      }
      print('Error fetching teacher data: $e');
    }
  }

  // Combine fetch operations
  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _fetchUserBookedSessions();
      await _fetchSharingClassData();
    } catch (e) {
      print('Error fetching data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Fetch the current user's bookedSessions
  Future<void> _fetchUserBookedSessions() async {
    if (currentUser != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.teacherData['provider'])
          .get();
      final data = userDoc.data();
      if (data != null && data['createdSessions'] != null) {
        setState(() {
          userBookedSessions = List<String>.from(data['createdSessions']);
        });
      }
    }
  }

  void _saveBooking(int points, String id) async {
    bool hasEnoughPoints = await _checkUserPoints(points);
    if (hasEnoughPoints) {
      bool confirmed = await _showConfirmationDialog(points); // 弹出确认对话框

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
          await _deductPoints(userId, points);
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
            'bookedSessions': FieldValue.arrayUnion([id])
          });

          Navigator.of(context).pop(); // 关闭上传弹窗

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

  Future<bool> _checkUserPoints(int requiredPoints) async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      debugPrint("Error: User is not logged in.");
      return false; // 直接返回 false 避免崩溃
    }

    DocumentSnapshot snapshot =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (snapshot.exists) {
      int currentPoints = (snapshot['points'] ?? 0) as int;
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
        .doc(widget.teacherData['provider']);

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
  Future<bool> _showConfirmationDialog(int points) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Confirm Submission'),
              content: Text(
                  'Submitting this will deduct $points points. Do you want to continue?'),
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

  // Check if a session has already passed
  bool isSessionPast(String dateStr, String endTimeStr) {
    try {
      // Parse the date string (e.g., "13 March 2025")
      DateFormat dateFormat = DateFormat("d MMMM yyyy");
      DateTime sessionDate = dateFormat.parse(dateStr);

      // Parse the end time (e.g., "7:30pm")
      RegExp timeRegex = RegExp(r"(\d+):(\d+)(am|pm)", caseSensitive: false);
      final match = timeRegex.firstMatch(endTimeStr);

      if (match != null) {
        int hours = int.parse(match.group(1)!);
        int minutes = int.parse(match.group(2)!);
        String period = match.group(3)!.toLowerCase();

        // Convert to 24-hour format
        if (period == "pm" && hours < 12) {
          hours += 12;
        } else if (period == "am" && hours == 12) {
          hours = 0;
        }

        // Create a DateTime object with both date and time
        DateTime sessionEndDateTime = DateTime(
          sessionDate.year,
          sessionDate.month,
          sessionDate.day,
          hours,
          minutes,
        );

        // Compare with current time
        return DateTime.now().isAfter(sessionEndDateTime);
      }

      // If time parsing fails, just compare the date
      return DateTime.now().isAfter(DateTime(
          sessionDate.year, sessionDate.month, sessionDate.day, 23, 59, 59));
    } catch (e) {
      print('Error parsing date/time: $e');
      return false; // Default to upcoming if parsing fails
    }
  }

  Future<void> _fetchSharingClassData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Reset lists
      upcomingBookings = [];
      pastBookings = [];

      // 获取用户的 bookedSessions
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.teacherData['provider'])
          .get();
      final data = userDoc.data();
      if (data == null || data['createdSessions'] == null) return;

      List<String> createdSessions = List<String>.from(data['createdSessions']);

      // 遍历 bookedSessions 获取 class 和 sharing 数据
      for (String sessionId in createdSessions) {
        // Process class data
        final classSnapshot = await _classRef.child(sessionId).get();
        if (classSnapshot.exists) {
          Map<dynamic, dynamic> classItem =
              classSnapshot.value as Map<dynamic, dynamic>;
          Map<String, dynamic> bookingData = {
            'key': sessionId,
            'type': 'class',
            ...Map<String, dynamic>.from(classItem),
          };

          // Check if session is past or upcoming
          if (isSessionPast(
              bookingData['date'] ?? '', bookingData['endTime'] ?? '')) {
            pastBookings.add(bookingData);
          } else {
            upcomingBookings.add(bookingData);
          }
        }

        // Process sharing data
        final sharingSnapshot = await _sharingRef.child(sessionId).get();
        if (sharingSnapshot.exists) {
          Map<dynamic, dynamic> sharingItem =
              sharingSnapshot.value as Map<dynamic, dynamic>;
          Map<String, dynamic> bookingData = {
            'key': sessionId,
            'type': 'sharing',
            ...Map<String, dynamic>.from(sharingItem),
          };

          // Check if session is past or upcoming
          if (isSessionPast(
              bookingData['date'] ?? '', bookingData['endTime'] ?? '')) {
            pastBookings.add(bookingData);
          } else {
            upcomingBookings.add(bookingData);
          }
        }
      }

      // Sort bookings by date (newest first for upcoming, oldest first for past)
      upcomingBookings.sort((a, b) {
        try {
          DateTime dateA = DateFormat("d MMMM yyyy").parse(a['date'] ?? '');
          DateTime dateB = DateFormat("d MMMM yyyy").parse(b['date'] ?? '');
          return dateA.compareTo(dateB); // Ascending for upcoming
        } catch (e) {
          return 0;
        }
      });

      pastBookings.sort((a, b) {
        try {
          DateTime dateA = DateFormat("d MMMM yyyy").parse(a['date'] ?? '');
          DateTime dateB = DateFormat("d MMMM yyyy").parse(b['date'] ?? '');
          return dateB.compareTo(dateA); // Descending for past
        } catch (e) {
          return 0;
        }
      });

      // 更新状态
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error fetching data: $e');
    }
  }

  Widget _buildBookingsList(List<Map<String, dynamic>> bookings) {
    if (bookings.isEmpty) {
      return Center(
        child: Text("No booking data.", style: TextStyle(color: Colors.grey)),
      );
    } else
      return SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Column(
            children: [
              ...bookings.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              SharingClassDetailPage(data: item),
                        ),
                      );
                    },
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      shadowColor: Colors.grey.shade200,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title
                                  Text(
                                    item['name'] ?? 'Unknown Name',
                                    //maxLines: 2,
                                    //overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: const Color(0xFF171A1F),
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  // Date
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today,
                                          size: 16, color: Colors.black),
                                      const SizedBox(width: 6),
                                      Text(
                                        item['date'] ?? 'Unknown Date',
                                        style: GoogleFonts.manrope(
                                          fontSize: 12,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),

                                  // Time
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time,
                                          size: 16, color: Colors.black),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${item['startTime']} - ${item['endTime']}',
                                        style: GoogleFonts.manrope(
                                          fontSize: 12,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),

                                  // Link
                                  Row(
                                    children: [
                                      const Icon(Icons.attach_money_rounded,
                                          size: 16, color: Colors.black),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            // Implement your link action
                                          },
                                          child: Text(
                                            '${(item['point'] == 0) ? 'Free' : '${item['point']} points'}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.manrope(
                                              fontSize: 12,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(120.0),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage:
                      _profilePicUrl != null && _profilePicUrl!.isNotEmpty
                          ? NetworkImage(_profilePicUrl!)
                          : null, // Replace with actual profile picture URL
                ),
                const SizedBox(height: 8),
                TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(text: 'Upcoming'),
                    Tab(text: 'Past'),
                  ],
                  indicatorColor: Colors.orange.shade700,
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.grey[400],
                ),
              ],
            ),
          ),
          centerTitle: true,
          title: Text(_fullName)),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // Upcoming Bookings Tab
                _buildBookingsList(upcomingBookings),

                // Past Bookings Tab
                _buildBookingsList(pastBookings),
              ],
            ),
    );
  }
}
