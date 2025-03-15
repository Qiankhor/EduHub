import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_education/models/QuizSet.dart';
import 'package:my_education/screens/quiz_page.dart';
import 'package:my_education/screens/robot_chat_page.dart';

class QuizSubjectPage extends StatefulWidget {
  final String categoryName;

  QuizSubjectPage({required this.categoryName});

  @override
  _QuizSubjectPageState createState() => _QuizSubjectPageState();
}

class _QuizSubjectPageState extends State<QuizSubjectPage> {
  final DatabaseReference _quizRef =
      FirebaseDatabase.instance.ref().child('quiz');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, List<QuizSet>> quizSetsByCategory = {};
  List<QuizSet> quizSets = [];
  List<String> subjects = [];
  String? selectedSubject;

  @override
  void initState() {
    super.initState();
    _fetchQuizData();
  }

  Future<void> _fetchQuizData() async {
    try {
      DataSnapshot categorySnapshot =
          await _quizRef.child(widget.categoryName).get();

      if (categorySnapshot.exists) {
        Map<dynamic, dynamic> subjectsData =
            categorySnapshot.value as Map<dynamic, dynamic>;

        List<QuizSet> fetchedQuizSets = [];
        Set<String> uniqueSubjects = {}; // To keep track of unique subjects

        for (var subjectEntry in subjectsData.entries) {
          String subjectName = subjectEntry.key;
          uniqueSubjects.add(subjectName); // Add subject to set

          Map<dynamic, dynamic> setsData =
              subjectEntry.value as Map<dynamic, dynamic>;

          for (var setEntry in setsData.entries) {
            String setName = setEntry.key;
            Map<dynamic, dynamic> setData =
                setEntry.value as Map<dynamic, dynamic>;

            if (setName.contains('Set ') &&
                (setData.containsKey('approve')
                    ? setData['approve'] != false
                    : true)) {
              String? providerId = setData['provider'] as String;
              String providerName = 'Unknown';

              DocumentSnapshot providerSnapshot =
                  await _firestore.collection('users').doc(providerId).get();
              Map<String, dynamic>? providerData =
                  providerSnapshot.data() as Map<String, dynamic>?;

              providerName = providerSnapshot.exists
                  ? (providerData?['fullName'] ?? 'Unknown')
                  : 'Unknown';

              fetchedQuizSets.add(
                QuizSet(
                  categoryName: widget.categoryName,
                  subjectName: subjectName,
                  setName: setName,
                  questionsCount: setData.length,
                  providerName: providerName,
                  setData: setData,
                  providerId: providerId,
                ),
              );
            }
          }
        }

        setState(() {
          quizSets = fetchedQuizSets;
          subjects = uniqueSubjects.toList(); // Convert set to list for buttons
        });
      } else {
        print('No subjects found for this category.');
      }
    } catch (e) {
      print('Error fetching quiz data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter quiz sets based on selected subject
    List<QuizSet> displayedQuizSets = selectedSubject == null
        ? quizSets.where((quizSet) {
            // Filter out subjects that have no approved sets
            return quizSets.any((set) =>
                set.subjectName == quizSet.subjectName &&
                set.setData['approve'] != false);
          }).toList()
        : quizSets
            .where((quizSet) =>
                quizSet.subjectName == selectedSubject &&
                quizSet.setData['approve'] != false)
            .toList();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('${widget.categoryName} subjects',
            style: GoogleFonts.poppins()),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        children: [
          SizedBox(height: 16),
          // Subject selection buttons
          Row(
            children: [
              SizedBox(width: 16),
              Text('Subject', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(width: 16),
              Expanded(
                // Wrap SingleChildScrollView with Expanded
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: subjects.where((subject) {
                      // Only include subjects with at least one approved set
                      return quizSets.any((quizSet) =>
                          quizSet.subjectName == subject &&
                          quizSet.setData['approve'] != false);
                    }).map((subject) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: ChoiceChip(
                          label: Text(subject),
                          selected: selectedSubject == subject,
                          onSelected: (isSelected) {
                            setState(() {
                              selectedSubject = isSelected ? subject : null;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: displayedQuizSets.isEmpty
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: displayedQuizSets.length,
                    itemBuilder: (context, index) {
                      QuizSet quizSet = displayedQuizSets[index];
                      return QuizSetCard(quizSet: quizSet);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => RobotChatPage()));
        },
        shape: CircleBorder(),
        backgroundColor: Colors.orange.shade700,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('images/robot.png'),
        ),
      ),
    );
  }
}

class QuizSetCard extends StatelessWidget {
  final QuizSet quizSet;

  QuizSetCard({required this.quizSet});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10), // Customize corner radius
      ),
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${quizSet.subjectName} - ${quizSet.setName}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Total questions: ${quizSet.questionsCount - 3}'),
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
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => QuizPage(quizSet: quizSet)));
                },
                child: Text('Attempt Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
