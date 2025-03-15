import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_education/admin/settings_admin.dart';
import 'package:my_education/current_user.dart';
import 'package:my_education/models/Teachers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_education/models/class_sharing.dart';
import 'package:my_education/screens/booking_screen.dart';
import 'package:my_education/screens/chat_screen.dart';
import 'package:my_education/screens/edushare_screen.dart';
import 'package:my_education/screens/event_all.dart';
import 'package:my_education/screens/past_year.dart';
import 'package:my_education/screens/quiz_category.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:my_education/screens/robot_chat_page.dart';
import 'package:my_education/screens/settings_screen.dart';
import 'package:my_education/screens/edumart_screen.dart';
import 'package:my_education/screens/survey.dart';
import 'package:my_education/screens/teacher_all.dart';
import 'package:my_education/tutor.dart';
import 'package:my_education/services/current_user_service.dart';
import 'package:my_education/services/tutor_service.dart';

class HomePage extends StatefulWidget {
  Teacher teacher;
  HomePage(this.teacher);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseReference _promotionalEventRef =
      FirebaseDatabase.instance.ref().child('promotionalEvent');
  final DatabaseReference _teacherRef =
      FirebaseDatabase.instance.ref().child('teacherInfo');
  final DatabaseReference _classRef =
      FirebaseDatabase.instance.ref().child('class');
  final DatabaseReference _sharingRef =
      FirebaseDatabase.instance.ref().child('sharing');

  final TutorService _tutorService = TutorService();
  final UserService _currentUserService = UserService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> promotionalEventData = [];
  List<Map<String, dynamic>> classData = [];
  List<Map<String, dynamic>> sharingData = [];
  String _fullName = '';
  int points = 0;
  bool _loading = true;
  int _selectedIndex = 0;
  String userType = "";
  List<Tutor> tutors = [];
  CurrentUser currentUser = CurrentUser.defaultUser();
  List<Widget>? _pages;
  final PageController _pageController = PageController();
  late Timer _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchPromotionalEventData();
    _initializePages();
    _initializeData();
    _startAutoScroll();
    _fetchSharingClassData();
  }

  @override
  void dispose() {
    if (_timer.isActive) {
      _timer.cancel();
    }
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(Duration(seconds: 3), (timer) {
      if (!mounted || !_pageController.hasClients) return; // 避免崩溃

      setState(() {
        if (_currentPage < promotionalEventData.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0; // 回到第一张
        }
      });

      _pageController.animateToPage(
        _currentPage,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  String _formatText(String text) {
    TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: GoogleFonts.poppins(fontSize: 12)),
      maxLines: 2,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 200); // 设置最大宽度（可调整）

    int lines = textPainter.computeLineMetrics().length;

    return lines == 1 ? '$text\n' : text; // 只有一行时添加 `\n`
  }

  Future<void> _initializeData() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      tutors = await _tutorService.fetchTutors();
      currentUser =
          await _currentUserService.fetchCurrentUser(user?.uid ?? '') ??
              CurrentUser.defaultUser();
    } catch (e) {
      print('Error initializing data: $e');
    }
  }

  void _initializePages() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        var userData = userDoc.data() as Map<String, dynamic>;
        userType = userData['userType'];

        // 根据用户类型决定设置页面
        Widget settingsPage =
            userType == 'admin' ? SettingsAdminPage() : SettingsPage();
        if (mounted)
          setState(() {
            _pages = [
              HomePage(Teacher(
                name: '',
                university: '',
                imageAsset: '',
                rating: 0.0,
                reviews: 0,
              )),
              EduMartPage(),
              EduShareScreen(),
              ChatPage(),
              settingsPage,
            ];
          });
      }
    }
  }

  Future<void> _fetchPromotionalEventData() async {
    try {
      DataSnapshot snapshot = await _promotionalEventRef.get();
      if (snapshot.exists) {
        Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        if (mounted)
          setState(() {
            promotionalEventData = data.entries
                .map((entry) => {
                      'key': entry.key,
                      ...Map<String, dynamic>.from(
                          entry.value as Map<dynamic, dynamic>)
                    })
                .where((item) => item['approve'] == true)
                .toList();
          });
      } else {
        print('No promotionalEvent data found.');
        if (mounted)
          setState(() {
            promotionalEventData = [];
          });
      }
    } catch (e) {
      print('Error fetching promotionalEvent data: $e');
      if (mounted) setState(() {});
    }
  }

  Future<void> _fetchSharingClassData() async {
    try {
      final classSnapshotFuture = _classRef.get();
      final sharingSnapshotFuture = _sharingRef.get();

      final DataSnapshot classSnapshot = await classSnapshotFuture;
      final DataSnapshot sharingSnapshot = await sharingSnapshotFuture;
      if (classSnapshot.exists) {
        Map<dynamic, dynamic> data =
            classSnapshot.value as Map<dynamic, dynamic>;
        classData = data.entries
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
        sharingData = data.entries
            .map((entry) => {
                  'key': entry.key,
                  ...Map<String, dynamic>.from(
                      entry.value as Map<dynamic, dynamic>)
                })
            .where((item) => item['approve'] == true)
            .toList();
      }
    } catch (e) {
      print('Error fetching class data: $e');
      if (mounted) setState(() {});
    }
  }

  Future<void> _fetchUserData() async {
    try {
      // Get current user
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Fetch user data from Firestore
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection(
                'users') // or 'users' based on your Firestore collection name
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          // Get the fullName field
          if (mounted)
            setState(() {
              _fullName = userDoc['fullName'] ?? 'No Name';
              points = userDoc['points'] != null ? userDoc['points'] as int : 0;

              _loading = false;
            });
        } else {
          if (mounted)
            setState(() {
              _fullName = 'User not found';
              points = 0;
              _loading = false;
            });
        }
      } else {
        if (mounted)
          setState(() {
            _fullName = 'No user logged in';
            points = 0;
            _loading = false;
          });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _fullName = 'Error fetching user data';
          points = 0;
          _loading = false;
        });
      print('Error fetching user data: $e');
    }
  }

  final List<String> catNames = [
    'Quiz',
    'Practices',
    'Survey',
  ];
  void _onItemTapped(int index) {
    if (mounted)
      setState(() {
        _selectedIndex = index;
      });
  }

  final List<Color> catColor = [
    Colors.orange.shade700,
    Colors.orange.shade700,
    Colors.orange.shade700,
  ];

  final List<Icon> catIcon = [
    Icon(Icons.quiz, color: Colors.white, size: 50),
    Icon(Icons.book, color: Colors.white, size: 50),
    Icon(Icons.assignment, color: Colors.white, size: 50),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedIndex == 0
          ? AppBar(
              automaticallyImplyLeading: false,
              centerTitle: false,
              elevation: 1.0,
              title: Text(
                'Hello, $_fullName!',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              actions: [
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => RobotChatPage()),
                    );
                  },
                  icon: Image.asset(
                    'images/robot2.png',
                    width: 24, // Adjust icon size as needed
                    height: 24,
                  ),
                ),
              ],
            )
          : null,
      body: _selectedIndex == 0
          ? SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SizedBox(
                      height:
                          MediaQuery.of(context).size.height * 0.4, // 控制广告区域高度
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: promotionalEventData.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentPage = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          var item = promotionalEventData[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      EventDetailPage(eventData: item),
                                ),
                              );
                            },
                            child: Stack(
                              children: [
                                // 背景图片
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    image: DecorationImage(
                                      image: NetworkImage(item['imagePath']!),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(context,
                          MaterialPageRoute(builder: (context) => EventAll()));
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 25, bottom: 8),
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Row(
                          mainAxisSize: MainAxisSize
                              .min, // Ensures it only takes the necessary space
                          children: [
                            Text(
                              'View more',
                              style: GoogleFonts.manrope(
                                fontWeight: FontWeight.w400,
                                fontSize: 14,
                                height: 1.6,
                                color: Colors.orange[700],
                              ),
                            ),
                            const SizedBox(
                                width:
                                    4), // Adds some spacing between the text and icon
                            Icon(
                              Icons
                                  .arrow_forward_ios, // You can also use Icons.arrow_right
                              size: 14, // Adjust size to match text
                              color: Colors.orange[700], // Match the text color
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16),
                        child: Container(
                          child: Text(
                            'Categories',
                            style: GoogleFonts.getFont(
                              'Poppins',
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              height: 1.6,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 8, left: 16, right: 16),
                    child: Container(
                      padding: const EdgeInsets.all(0.0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Always use 3 columns to keep buttons in one line
                          final crossAxisCount = 3;

                          // Calculate width for each item
                          final itemWidth =
                              (constraints.maxWidth - 32) / crossAxisCount;

                          // Use a fixed aspect ratio that works well across devices
                          final aspectRatio = 1.0;

                          return GridView.builder(
                            itemCount: catNames.length,
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              childAspectRatio: aspectRatio,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                onTap: () async {
                                  if (catNames[index] == "Quiz") {
                                    Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                QuizCategoryPage()));
                                  }
                                  if (catNames[index] == "Practices") {
                                    Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                QuizPastYearPage()));
                                  }
                                  if (catNames[index] == "Survey") {
                                    Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                SurveyPage()));
                                  }
                                },
                                child: Container(
                                  margin: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: catColor[index],
                                    shape: BoxShape.rectangle,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        catIcon[index].icon,
                                        color: Colors.white,
                                        // Responsive icon size
                                        size: constraints.maxWidth < 360
                                            ? 30
                                            : 40,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        catNames[index],
                                        style: TextStyle(
                                          fontSize: constraints.maxWidth < 360
                                              ? 12
                                              : 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  if (sharingData.isNotEmpty || classData.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                              left: 16, right: 16, top: 16),
                          child: Container(
                            child: Text(
                              'Sharing Sessions/Classes',
                              style: GoogleFonts.getFont(
                                'Poppins',
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                height: 1.6,
                                color: Color(0xFF171A1F),
                              ),
                              softWrap: true,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Padding(
                          padding:
                              EdgeInsets.only(left: 16, right: 16, top: 16),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => TeacherAll()));
                              //Navigator.push(context, MaterialPageRoute(builder: (context)=>TutorScreen(tutors: tutors, currentUser: currentUser)));
                            },
                            child: Text(
                              'View more',
                              style: GoogleFonts.getFont(
                                'Manrope',
                                fontWeight: FontWeight.w400,
                                fontSize: 14,
                                height: 1.6,
                                color: Colors.orange[700],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding:
                          const EdgeInsets.only(left: 8, right: 8, bottom: 16),
                      child: Row(children: [
                        ...[...sharingData, ...classData].map((item) {
                          return SizedBox(
                            width: 200.0, // 固定每个项的宽度
                            child: Padding(
                              padding: const EdgeInsets.all(8),
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
                                child: Wrap(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: 8, top: 8),
                                      child: Card(
                                        color: Theme.of(context)
                                            .scaffoldBackgroundColor,
                                        shadowColor: Colors.transparent,
                                        margin: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        //elevation: 2,
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 5),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              item['imagePath'] != null &&
                                                      item['imagePath']
                                                          .isNotEmpty
                                                  ? Container(
                                                      height: 180,
                                                      width: double.infinity,
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        image: DecorationImage(
                                                          image: NetworkImage(
                                                              item[
                                                                  'imagePath']),
                                                          fit: BoxFit.fill,
                                                        ),
                                                      ),
                                                    )
                                                  : Container(),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 8, right: 8, top: 8),
                                                child: Text(
                                                  _formatText(item['name'] ??
                                                      'Unknown Name'),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                    color: Color(0xFF171A1F),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 8, right: 8),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.calendar_today,
                                                      color: Colors.grey[600],
                                                      size: 16,
                                                    ),
                                                    SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        '${item['date'] ?? 'Unknown'}',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            GoogleFonts.manrope(
                                                          fontWeight:
                                                              FontWeight.w400,
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 8, right: 8),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.access_time,
                                                      color: Colors.grey[600],
                                                      size: 16,
                                                    ),
                                                    SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        '${item['startTime']} - ${item['endTime']}',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            GoogleFonts.manrope(
                                                          fontWeight:
                                                              FontWeight.w400,
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 8, right: 8),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .attach_money_rounded,
                                                      color: Colors.grey[600],
                                                      size: 16,
                                                    ),
                                                    SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        '${(item['point'] == 0) ? 'Free' : '${item['point']} points'}',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            GoogleFonts.manrope(
                                                          fontWeight:
                                                              FontWeight.w400,
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
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
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ]),
                    ),
                  )
                ],
              ),
            )
          : _pages?[_selectedIndex],

      floatingActionButtonLocation: userType != 'admin'
          ? FloatingActionButtonLocation.centerDocked
          : FloatingActionButtonLocation.endFloat,

      bottomNavigationBar: BottomAppBar(
        shape: userType != 'admin' ? CircularNotchedRectangle() : null,
        notchMargin: 6.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildNavItem(Icons.home, "Home", 0),
            _buildNavItem(Icons.shopping_bag, "EduMart", 1),
            _buildNavItem(Icons.schedule_sharp, "EduShare", 2),
            _buildNavItem(Icons.chat, "Chat", 3),
            _buildNavItem(Icons.settings, "Settings", 4),
          ],
        ),
      ),

      /// **封装 Bottom Navigation Item**
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min, // 让 Column 仅占用最小空间
        children: [
          Icon(
            icon,
            color: _selectedIndex == index ? Colors.orange[700] : Colors.grey,
          ),
          SizedBox(height: 4), // 控制图标和文本间距
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: _selectedIndex == index ? Colors.orange[700] : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
