import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:my_education/models/class_sharing.dart';
import 'package:url_launcher/url_launcher.dart';

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
              // Determine if session is past
              bool isPastSession =
                  isSessionPast(item['date'] ?? '', item['endTime'] ?? '');

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
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

                                // Link row - show meeting link for upcoming, recording link for past
                                Row(
                                  children: [
                                    Icon(
                                        isPastSession
                                            ? Icons.video_library
                                            : Icons.link,
                                        size: 16,
                                        color: Colors.black),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          // For past sessions, use recording link; otherwise use meeting link
                                          String? linkText = isPastSession
                                              ? (item['recording'] ?? '')
                                              : (item['link'] ?? '');

                                          if (linkText!.isNotEmpty) {
                                            Clipboard.setData(
                                                ClipboardData(text: linkText));
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(isPastSession
                                                      ? 'Recording link copied to clipboard!'
                                                      : 'Link copied to clipboard!')),
                                            );
                                          }
                                        },
                                        child: Text(
                                          isPastSession
                                              ? (item['recording'] != null &&
                                                      item['recording']
                                                          .isNotEmpty
                                                  ? item['recording']
                                                  : 'No Recording')
                                              : (item['link'] ?? 'No Link'),
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
                                if (!isPastSession)
                                  ElevatedButton(
                                    onPressed: () {
                                      if (item['link'] != null &&
                                          item['link'].isNotEmpty) {
                                        _launchURL(item['link']);
                                      } else {
                                        _showAddLinkDialog(
                                            context, item, 'link');
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 5),
                                    ),
                                    child: Text(
                                      item['link'] != null &&
                                              item['link'].isNotEmpty
                                          ? 'Join'
                                          : 'Add Link',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),

                                // Recording Button (only for past sessions)
                                if (isPastSession)
                                  ElevatedButton(
                                    onPressed: () {
                                      if (item['recording'] != null &&
                                          item['recording'].isNotEmpty) {
                                        _launchURL(item['recording']);
                                      } else {
                                        _showAddLinkDialog(
                                            context, item, 'recording');
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 5),
                                    ),
                                    child: Text(
                                      item['recording'] != null &&
                                              item['recording'].isNotEmpty
                                          ? 'View Recording'
                                          : 'Add Recording',
                                      style: TextStyle(color: Colors.white),
                                    ),
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

  void _showAddLinkDialog(
      BuildContext context, Map<String, dynamic> item, String linkType) {
    TextEditingController linkController = TextEditingController();
    String? errorMessage;

    // Determine dialog title based on link type
    String dialogTitle =
        linkType == 'recording' ? "Add Recording Link" : "Add Meeting Link";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: SingleChildScrollView(
                      reverse: true, // Keeps field visible when keyboard opens
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            Text(
                              dialogTitle,
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: linkController,
                              decoration: InputDecoration(
                                hintText: linkType == 'recording'
                                    ? "Enter recording link"
                                    : "Enter meeting link",
                                errorText:
                                    errorMessage, // Shows error below field
                              ),
                            ),
                            const SizedBox(
                                height: 5), // Space for error message
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    String enteredLink =
                                        linkController.text.trim();
                                    if (_isValidMeetingLink(enteredLink)) {
                                      try {
                                        // Update Firebase
                                        String sessionType =
                                            item['type'] ?? 'sharing';
                                        String dbPath =
                                            '$sessionType/${item['id']}/$linkType';
                                        DatabaseReference sessionRef =
                                            FirebaseDatabase.instance
                                                .ref(dbPath);

                                        await sessionRef.set(
                                            enteredLink); // Set link in Firebase

                                        await _fetchSharingClassData();

                                        if (mounted) {
                                          setState(() {}); // Ensure UI updates
                                        }

                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text(linkType ==
                                                      'recording'
                                                  ? "Recording link added successfully!"
                                                  : "Link added successfully!")),
                                        );
                                      } catch (e) {
                                        setDialogState(() {
                                          errorMessage =
                                              "Failed to add link. Try again.";
                                        });
                                      }
                                    } else {
                                      setDialogState(() {
                                        errorMessage = "Invalid link!";
                                      });
                                    }
                                  },
                                  child: const Text("Add"),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  bool _isValidMeetingLink(String url) {
    return Uri.tryParse(url)?.hasAbsolutePath ?? false;
  }

  Future<void> _launchURL(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      print('Error: $e');
    }
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
