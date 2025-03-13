import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_education/admin/sharing_class.dart';
import 'package:my_education/admin/sharing_session.dart';
import 'package:my_education/models/Teachers.dart';
import 'package:my_education/screens/home_page.dart';
import 'package:my_education/admin/pastyear_admin.dart';
import 'package:my_education/admin/promotional_admin.dart';
import 'package:my_education/admin/quiz_page_admin.dart';
import 'package:my_education/admin/report_admin.dart';
import 'package:my_education/admin/survey_admin.dart';
import 'package:my_education/admin/teacher_admin.dart';
import 'package:my_education/screens/chat_screen.dart';
import 'package:my_education/screens/edumart_screen.dart';
import 'package:my_education/screens/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsAdminPage extends StatefulWidget {
  
  SettingsAdminPage();

  @override
  _SettingsAdminPageState createState() => _SettingsAdminPageState();
}

  class _SettingsAdminPageState extends State<SettingsAdminPage> {
        String _fullName = '';
     String? _profilePicUrl;
     bool _loading = true;
    int _selectedIndex = 0;
    List<Widget>? _pages;
     @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(Teacher(name: '', university: '', imageAsset: '', rating: 0.0, reviews: 0)),
      ChatPage(),
      EduMartPage(),
      SettingsAdminPage(),
    ];
  }
      final List<String> catNames = [
    'Quiz',
    'Event',
    'Survey',
    'Past Year',
    'Teacher',
    'Report',
    'Register Sharing Sessions',
    'Register Class',
  ];
 void _onItemTapped(int index) {
  if(mounted){
    setState(() {
      _selectedIndex = index;
    });
  }
  }
  final List<Color> catColor = [
    Color(0xFF002c2b),
    Colors.green,
    Colors.orange,
    const Color.fromRGBO(13, 71, 161, 1),
    Colors.purple,
    Colors.red,
    Colors.pink,
    Colors.greenAccent
  ];
    final List<Icon> catIcon = [
    //Icon(Icons.category, color: Colors.white, size: 30),
    Icon(Icons.quiz, color: Colors.white, size: 30),
    Icon(Icons.campaign, color: Colors.white, size: 30),
    Icon(Icons.assignment, color: Colors.white, size: 30),
    Icon(Icons.school, color: Colors.white, size: 30),
    Icon(Icons.person, color: Colors.white, size: 30),
    Icon(Icons.warning_rounded, color: Colors.white, size: 30),
    Icon(Icons.share, color: Colors.white, size: 30),
    Icon(Icons.category, color: Colors.white, size: 30),

  ];
   

  @override
  Widget build(BuildContext context){
    return Scaffold(
         appBar: AppBar(
          automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text('Management', style: GoogleFonts.poppins()),
      ),
         body: _selectedIndex == 0
    ? SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),
              // 标题部分
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Categories',
                  style: GoogleFonts.getFont(
                    'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    height: 1.6,
                    color: Color(0xFF171A1F),
                  ),
                ),
              ),
              SizedBox(height: 8),
              // GridView 部分
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  itemCount: catNames.length,
                  shrinkWrap: true, // 让 GridView 高度适应内容
                  physics: NeverScrollableScrollPhysics(), // 禁用 GridView 滚动，交给父级滚动
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 3 / 1.5,
                  ),
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () async {
                        // 导航逻辑
                        if (catNames[index] == "Quiz") {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => QuizPageAdmin()),
                          );
                        } else if (catNames[index] == "Past Year") {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => PastYearPageAdmin()),
                          );
                        } else if (catNames[index] == "Event") {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    PromotionalEventPage()),
                          );
                        } else if (catNames[index] == "Survey") {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => SurveyPageAdmin()),
                          );
                        } else if (catNames[index] == "Teacher") {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => TeacherAdminPage()),
                          );
                        } else if (catNames[index] == "Report") {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ReportPage()),
                          );
                        }
                        else if (catNames[index] == "Register Sharing Sessions") {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => SharingSessionPageAdmin()),
                          );
                        }
                        else if (catNames[index] == "Register Class") {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ClassPageAdmin()),
                          );
                        }
                      },
                      child: Container(
                        margin: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              spreadRadius: 2,
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                color: catColor[index],
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  bottomLeft: Radius.circular(10),
                                ),
                              ),
                              child: Center(
                                child: catIcon[index],
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                catNames[index],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 32),
              // Log Out 按钮部分
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text(
                            "Log Out",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          content: Text("Are you sure you want to log out?"),
                          actions: [
                            TextButton(
                              child: Text("No"),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                            TextButton(
                              child: Text("Yes"),
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await _logout(context);
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: Padding(
                   padding: const EdgeInsets.only(top: 12, bottom: 12),
                    child: Text(
                      'Log Out',
                      style: GoogleFonts.getFont(
                        'Poppins',
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        height: 1.4,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 15), // 增加一些底部间距
            ],
          ),
        ),
      )
    : _pages?[_selectedIndex],

        
        
      
    );
    
  }
     Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
      
    } catch (e) {
      print('Error signing out: $e');
    }
    
  
}
}