import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_education/screens/my_interests.dart';
import 'package:my_education/screens/my_sessions.dart';

class EduShareScreen extends StatelessWidget {
  const EduShareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Two tabs: Upcoming and Past
      child: Scaffold(
        appBar: AppBar(
          title: Text('EduShare', style: GoogleFonts.poppins()),
          automaticallyImplyLeading: false,
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: Color.fromARGB(255, 0, 0, 0),
            labelColor: Colors.black,
            tabs: [
              Tab(
                text: "My Interests",
              ),
              Tab(text: "My Sessions"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            MyInterestsScreen(),
            MySessionsScreen(),
          ],
        ),
      ),
    );
  }
}
