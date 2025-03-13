import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_education/models/QuizSet.dart';
import 'package:my_education/models/Teachers.dart';
import 'package:my_education/screens/create_quiz1.dart';
import 'package:my_education/screens/home_page.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_education/screens/quiz_subject.dart';
import 'package:my_education/screens/robot_chat_page.dart';

class QuizCategoryPage extends StatefulWidget {
  @override
  _QuizCategoryPageState createState() => _QuizCategoryPageState();
}

class _QuizCategoryPageState extends State<QuizCategoryPage> {
  final DatabaseReference _quizRef =
      FirebaseDatabase.instance.ref().child('quiz');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, List<QuizSet>> quizSetsByCategory = {};
  List<String> filteredCategoryNames = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchQuizData(); // Fetch data when the page is initialized
  }

  Future<void> _fetchQuizData() async {
    try {
      DataSnapshot categoriesSnapshot = await _quizRef.get();

      if (categoriesSnapshot.exists) {
        Map<dynamic, dynamic> categoriesData =
            categoriesSnapshot.value as Map<dynamic, dynamic>;

        // Map to store quiz sets by category
        Map<String, List<QuizSet>> fetchedQuizSetsByCategory = {};

        for (var categoryEntry in categoriesData.entries) {
          String categoryName = categoryEntry.key;
          Map<dynamic, dynamic> subjectsData =
              categoryEntry.value as Map<dynamic, dynamic>;

          List<QuizSet> quizSets = [];
          int approvedSubjectCount = 0;

          for (var subjectEntry in subjectsData.entries) {
            String subjectName = subjectEntry.key;
            Map<dynamic, dynamic> setsData =
                subjectEntry.value as Map<dynamic, dynamic>;

            // Filter quiz sets to only include approved ones
            bool hasApprovedSet = false;

            for (var setEntry in setsData.entries) {
              String setName = setEntry.key;
              Map<dynamic, dynamic> setData =
                  setEntry.value as Map<dynamic, dynamic>;

              // Check if this set is approved
              bool isApprovedSet = setData.containsKey('approve')
                  ? setData['approve'] == true
                  : true;

              if (isApprovedSet) {
                hasApprovedSet = true;

                String? providerId = setData['provider'] as String?;
                if (providerId != null) {
                  DocumentSnapshot providerSnapshot = await _firestore
                      .collection('users')
                      .doc(providerId)
                      .get();
                  Map<String, dynamic>? providerData =
                      providerSnapshot.data() as Map<String, dynamic>?;

                  String providerName = providerSnapshot.exists
                      ? (providerData?['fullName'] ?? 'Unknown')
                      : 'Unknown';

                  quizSets.add(
                    QuizSet(
                      categoryName: categoryName,
                      subjectName: subjectName,
                      setName: setName,
                      questionsCount: 0,
                      providerName: providerName,
                      setData: setData,
                      totalSetCount: 0, // This can be adjusted later
                      totalSubjectCount: 0, // Initialize totalSubjectCount
                    ),
                  );
                }
              }
            }

            // If any approved sets exist, count this subject
            if (hasApprovedSet) {
              approvedSubjectCount++;
            }
          }

          // Only add this category if it has at least one approved quiz set
          if (quizSets.isNotEmpty) {
            // Update the totalSubjectCount for each quiz set in the category
            for (var quizSet in quizSets) {
              quizSet.totalSubjectCount =
                  approvedSubjectCount; // Set the total subject count
            }

            fetchedQuizSetsByCategory[categoryName] = quizSets;
          }
        }

        // Update state with fetched data
        setState(() {
          quizSetsByCategory = fetchedQuizSetsByCategory.map(
            (key, value) => MapEntry(
              key,
              value..sort((a, b) => a.subjectName.compareTo(b.subjectName)),
            ),
          );

          filteredCategoryNames = quizSetsByCategory.keys.toList();
        });
      } else {
        // If no categories are found, reset the state to empty
        setState(() {
          quizSetsByCategory = {};
          filteredCategoryNames = [];
        });
        print('No categories found.');
      }
    } catch (e) {
      print('Error fetching quiz data: $e');
    }
  }

  void _filterCategories(String query) {
    setState(() {
      searchQuery = query.toLowerCase();
      filteredCategoryNames = quizSetsByCategory.keys
          .where((categoryName) =>
              categoryName.toLowerCase().contains(searchQuery))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Quiz', style: GoogleFonts.poppins()),
        leading: IconButton(
          onPressed: () {
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => HomePage(Teacher(
                        name: '',
                        university: '',
                        imageAsset: '',
                        rating: 0.0,
                        reviews: 0))));
          },
          icon: Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => CreateQuiz1()));
              },
              icon: Icon(Icons.add))
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: _filterCategories,
              decoration: InputDecoration(
                focusedBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: Colors.orange.shade700), // 聚焦时的边框颜色
                ),
                border: OutlineInputBorder(),
                labelText: 'Search Categories',
                suffixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: quizSetsByCategory.isEmpty
                ? Center(
                    child: Text('No data available',
                        style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: filteredCategoryNames.length,
                    itemBuilder: (context, index) {
                      String categoryName = filteredCategoryNames[index];
                      List<QuizSet> quizSets =
                          quizSetsByCategory[categoryName]!;

                      return _buildQuizCard(categoryName, quizSets);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizCard(String categoryName, List<QuizSet> quizSets) {
    // Only show one card per category
    return Card(
      margin: EdgeInsets.only(top: 10, bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              categoryName,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            // Show total subjects if there are approved sets
            if (quizSets.isNotEmpty)
              Text('Total subjects: ${quizSets.first.totalSubjectCount}'),
            if (quizSets.isEmpty) Text('No subjects available'),
            SizedBox(height: 8),
            SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                onPressed: quizSets.isNotEmpty
                    ? () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => QuizSubjectPage(
                                    categoryName: categoryName)));
                      }
                    : null, // Disable button if no subjects
                child: Text('Choose'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
