import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class MySessionsScreen extends StatefulWidget {
  const MySessionsScreen({super.key});

  @override
  _MySessionsScreenState createState() => _MySessionsScreenState();
}

class _MySessionsScreenState extends State<MySessionsScreen> {
  List<String> userCreatedSessions = []; // To store the user's booked sessions
  final DatabaseReference _classRef =
      FirebaseDatabase.instance.ref().child('class');
  final DatabaseReference _sharingRef =
      FirebaseDatabase.instance.ref().child('sharing');
  List<Map<String, dynamic>> upcomingBookings = [];
  List<Map<String, dynamic>> pastBookings = [];
  bool _isLoading = true; // Track loading state
  bool isUpcomingSelected = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // Combine fetch operations
  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _fetchUserCreatedSessions();
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
  Future<void> _fetchUserCreatedSessions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = userDoc.data();
      if (data != null && data['createdSessions'] != null) {
        setState(() {
          userCreatedSessions = List<String>.from(data['createdSessions']);
        });
      }
    }
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
          .doc(user.uid)
          .get();
      final data = userDoc.data();
      if (data == null || data['createdSessions'] == null) return;

      List<String> bookedSessions = List<String>.from(data['createdSessions']);

      // 遍历 bookedSessions 获取 class 和 sharing 数据
      for (String sessionId in bookedSessions) {
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
        child:
            Text("No Sessions Created.", style: TextStyle(color: Colors.grey)),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Column(
          children: [
            ...bookings.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
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
                          // Image (2/5 of the total width)
                          SizedBox(
                            width: MediaQuery.of(context).size.width *
                                0.4, // Explicit width
                            child: Container(
                              height: MediaQuery.of(context).size.width *
                                  0.4, // Square image
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: NetworkImage(item['imagePath']),
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Content (Remaining 3/5 width)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title
                                Text(
                                  item['name'] ?? 'Unknown Name',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: const Color(0xFF171A1F),
                                  ),
                                ),
                                const SizedBox(height: 5),

                                // Date
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today,
                                        size: 16, color: Colors.black),
                                    const SizedBox(width: 6),
                                    Text(
                                      item['date'] ?? 'Unknown Date',
                                      style: GoogleFonts.manrope(
                                          fontSize: 12, color: Colors.black),
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
                                          fontSize: 12, color: Colors.black),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),

                                // Link
                                Row(
                                  children: [
                                    const Icon(Icons.link,
                                        size: 16, color: Colors.black),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          // Implement your link action
                                        },
                                        child: Text(
                                          item['link'] ?? 'No Link',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.manrope(
                                            fontSize: 12,
                                            color: Colors.blue,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),

                                // Join button (only for upcoming sessions)
                                if (!isSessionPast(
                                    item['date'] ?? '', item['endTime'] ?? ''))
                                  ElevatedButton(
                                    onPressed: () {
                                      // Implement join action
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 5),
                                    ),
                                    child: const Text(
                                      'Join',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      )),
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
      body: Column(
        children: [
          const SizedBox(height: 10),

          // Toggle Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        isUpcomingSelected = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isUpcomingSelected
                            ? Colors.orange.shade700
                            : Colors.grey[300],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          bottomLeft: Radius.circular(10),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "Upcoming",
                        style: TextStyle(
                          color:
                              isUpcomingSelected ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        isUpcomingSelected = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !isUpcomingSelected
                            ? Colors.orange.shade700
                            : Colors.grey[300],
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "Past",
                        style: TextStyle(
                          color:
                              !isUpcomingSelected ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Content Section
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : isUpcomingSelected
                    ? _buildBookingsList(upcomingBookings)
                    : _buildBookingsList(pastBookings),
          ),
        ],
      ),
    );
  }
}
