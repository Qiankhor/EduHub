import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_education/models/Teacher_details_page.dart';
import 'package:my_education/models/Teachers.dart';
import 'package:my_education/models/class_sharing.dart';
import 'package:my_education/screens/create_class.dart';
import 'package:my_education/screens/create_teacher.dart';
import 'package:my_education/screens/home_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_education/screens/create_sharing.dart';

class TeacherAll extends StatefulWidget {
  @override
  _TeacherAllState createState() => _TeacherAllState();
}

class _TeacherAllState extends State<TeacherAll> {
  String _userType = '';
  String searchQuery = ''; // Variable to hold the search query
  List<Map<String, dynamic>> teacherData =
      []; // To hold the filtered teacher data
  final DatabaseReference _classRef =
      FirebaseDatabase.instance.ref().child('class');
  final DatabaseReference _sharingRef =
      FirebaseDatabase.instance.ref().child('sharing');
  List<Map<String, dynamic>> classData = [];
  List<Map<String, dynamic>> sharingData = [];

  @override
  void initState() {
    super.initState();
    _fetchSharingClassData();
    _fetchUserData();
  }

  Future<void> _fetchSharingClassData() async {
    try {
      final classSnapshotFuture = _classRef.get();
      final sharingSnapshotFuture = _sharingRef.get();

      final DataSnapshot classSnapshot = await classSnapshotFuture;
      final DataSnapshot sharingSnapshot = await sharingSnapshotFuture;

      List<Map<String, dynamic>> tempClassData = [];
      List<Map<String, dynamic>> tempSharingData = [];

      if (classSnapshot.exists) {
        Map<dynamic, dynamic> data =
            classSnapshot.value as Map<dynamic, dynamic>;
        tempClassData = data.entries
            .map((entry) => {
                  'key': entry.key,
                  ...Map<String, dynamic>.from(
                      entry.value as Map<dynamic, dynamic>)
                })
            .where((item) => item['approve'] == true)
            .toList();
      }

      if (sharingSnapshot.exists) {
        Map<dynamic, dynamic> data =
            sharingSnapshot.value as Map<dynamic, dynamic>;
        tempSharingData = data.entries
            .map((entry) => {
                  'key': entry.key,
                  ...Map<String, dynamic>.from(
                      entry.value as Map<dynamic, dynamic>)
                })
            .where((item) => item['approve'] == true)
            .toList();
      }

      // Update state after fetching data
      if (mounted) {
        setState(() {
          classData = tempClassData;
          sharingData = tempSharingData;
        });
      }
    } catch (e) {
      print('Error fetching class data: $e');
    }
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
              _userType = userDoc.data().toString().contains('userType')
                  ? userDoc['userType']
                  : null;
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  List<Map<String, dynamic>> _filterTeachers(
      List<Map<String, dynamic>> teachers) {
    if (searchQuery.isEmpty) return teachers;

    String query = searchQuery.toLowerCase().replaceAll(' ', '');

    return teachers.where((teacher) {
      String name =
          (teacher['name'] ?? '').toString().toLowerCase().replaceAll(' ', '');
      String field =
          (teacher['field'] ?? '').toString().toLowerCase().replaceAll(' ', '');
      String date =
          (teacher['date'] ?? '').toString().toLowerCase().replaceAll(' ', '');
      String startTime = (teacher['startTime'] ?? '')
          .toString()
          .toLowerCase()
          .replaceAll(' ', '');

      return name.contains(query) ||
          field.contains(query) ||
          date.contains(query) ||
          startTime.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HomePage(
                  Teacher(
                    name: '',
                    university: '',
                    imageAsset: '',
                    rating: 0.0,
                    reviews: 0,
                  ),
                ),
              ),
            );
          },
        ),
        actions: [
          IconButton(
            onPressed: () {
              showMenu(
                context: context,
                position: RelativeRect.fromLTRB(100, 80, 0, 0), // 位置可调整
                items: [
                  if (_userType != 'teacher')
                    PopupMenuItem(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => CreateTeacherPage()));
                        },
                        child: Row(
                          children: [
                            Icon(Icons.person_2, color: Colors.orange[700]),
                            SizedBox(
                              width: 20,
                            ),
                            Text("Apply as Mentor"),
                          ],
                        ),
                      ),
                    ),
                  PopupMenuItem(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    RegisterSharingSessionPage()));
                      },
                      child: Row(
                        children: [
                          Icon(Icons.share, color: Colors.red),
                          SizedBox(
                            width: 20,
                          ),
                          Text("Register Sharing Session"),
                        ],
                      ),
                    ),
                  ),
                  if (_userType == 'teacher')
                    PopupMenuItem(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => RegisterClassPage()));
                        },
                        child: Row(
                          children: [
                            Icon(Icons.app_registration_rounded,
                                color: Colors.purple),
                            SizedBox(
                              width: 20,
                            ),
                            Text("Register Class"),
                          ],
                        ),
                      ),
                    ),
                ],
              ).then((value) {
                if (value != null) {
                  // 这里可以根据选择的 value 进行相应的操作
                  print("Selected: $value");
                }
              });
            },
            icon: Icon(Icons.add),
          ),
        ],
        title: Text('Sharing Sessions/Classes', style: TextStyle()),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value; // Update the search query
                  });
                },
                decoration: InputDecoration(
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.orange.shade700),
                  ),
                  border: OutlineInputBorder(),
                  labelText: 'Search',
                  suffixIcon: Icon(Icons.search),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: _filterTeachers([...sharingData, ...classData]).isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            Icon(
                              Icons.search_off_rounded,
                              size: 56,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No class or tutor found.",
                              style: GoogleFonts.poppins(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : Wrap(
                        spacing: 12.0, // horizontal spacing between items
                        runSpacing: 16.0, // vertical spacing between rows
                        children:
                            _filterTeachers([...sharingData, ...classData])
                                .map((item) {
                          return SizedBox(
                            width: MediaQuery.of(context).size.width / 2 -
                                14, // Dynamically calculate width for 2 items per row
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Image container with rounded corners
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: item['imagePath'] != null &&
                                            item['imagePath'].isNotEmpty
                                        ? Container(
                                            height: 180,
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              image: DecorationImage(
                                                image: NetworkImage(
                                                    item['imagePath']),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            height: 180,
                                            width: double.infinity,
                                            color: Colors.grey[200],
                                          ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Title with ellipsis
                                  Text(
                                    item['name'] ?? 'Unknown Name',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Color(0xFF171A1F),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Date row
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        color: Colors.grey[600],
                                        size: 14,
                                      ),
                                      SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${item['date'] ?? 'Unknown'}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.manrope(
                                            fontWeight: FontWeight.w400,
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  // Time row
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        color: Colors.grey[600],
                                        size: 14,
                                      ),
                                      SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${item['startTime']} - ${item['endTime']}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.manrope(
                                            fontWeight: FontWeight.w400,
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  // Points row
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.attach_money_rounded,
                                        color: Colors.grey[600],
                                        size: 14,
                                      ),
                                      SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${item['point']} points',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.manrope(
                                            fontWeight: FontWeight.w400,
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
