import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_education/models/QuizSet.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_education/screens/create_quiz1.dart';
import 'package:my_education/screens/robot_chat_page.dart';

class QuizPage extends StatefulWidget {
  final QuizSet quizSet;

  QuizPage({required this.quizSet});

  @override
  _QuizPageState createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final DatabaseReference _quizRef = FirebaseDatabase.instance.ref().child('quiz');

  List<Question> _questions = [];
  Map<String, String?> _userAnswers = {}; // To store user answers
  Map<String, bool?> _answerCorrectness = {}; // To store correctness of user answers
  int _totalScore = 0;
  bool _resultsShown = false;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    try {
      final questionsSnapshot = await _quizRef
          .child(widget.quizSet.categoryName)
          .child(widget.quizSet.subjectName)
          .child(widget.quizSet.setName)
          .get();

      if (questionsSnapshot.exists) {
        final questionsData = questionsSnapshot.value;

        // Print the raw data for debugging
        print('Raw data: $questionsData');

        // Check if the data is a Map
        if (questionsData is Map<dynamic, dynamic>) {
          final questions = questionsData.entries
              .where((entry) => entry.value is Map<dynamic, dynamic> && entry.key.startsWith('Question'))
              .map((entry) {
                final questionKey = entry.key as String;
                final data = entry.value as Map<dynamic, dynamic>;

                // Get options and correct answer
                final options = {
                  'option1': data['option1'] as String? ?? '',
                  'option2': data['option2'] as String? ?? '',
                  'option3': data['option3'] as String? ?? '',
                };
                final correctAnswer = data['correctAnswer'] as String? ?? '';

                // Create a list of options including the correct answer
                final optionsList = [
                  {'key': 'option1', 'value': options['option1']!},
                  {'key': 'option2', 'value': options['option2']!},
                  {'key': 'option3', 'value': options['option3']!},
                  {'key': 'correctAnswer', 'value': correctAnswer},
                ];

                // Shuffle the options
                optionsList.shuffle();

                // Determine which option is the correct one after shuffling
                final correctOptionKey = optionsList.firstWhere(
                  (option) => option['value'] == correctAnswer,
                  orElse: () => {'key': 'option1', 'value': ''} // Provide a default value in case no match is found
                )['key']!;

                final shuffledOptions = {
                  for (var option in optionsList)
                    option['key']!: option['value']!
                };

                return Question(
                  id: questionKey,
                  question: data['question'] as String? ?? '',
                  options: shuffledOptions,
                  correctAnswer: correctOptionKey,
                );
              }).toList();

          setState(() {
            _questions = questions;
          });
        } else {
          print('Data is not a Map or is empty: $questionsData');
        }
      } else {
        print('No questions found.');
      }
    } catch (e) {
      print('Error fetching questions: $e');
    }
  }
void _submitQuiz() async {
  // Calculate the score and answer correctness
  int score = 0;
  final answerCorrectness = <String, bool?>{};

  for (var question in _questions) {
    final selectedOptionKey = _userAnswers[question.id];
    final selectedAnswer = question.options[selectedOptionKey ?? '']; // Get the value from the options map

    final isCorrect = selectedAnswer == question.options[question.correctAnswer];
    if (isCorrect) {
      score++;
    }
    answerCorrectness[question.id] = isCorrect;
  }

  // Update the state with the calculated score and answer correctness
  setState(() {
    _totalScore = score;
    _answerCorrectness = answerCorrectness;
   // _resultsShown = true; // Set the flag to show results and disable interactions
  });

  // Show confirmation dialog
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Submit Quiz'),
        content: Text('Are you sure you want to submit the quiz?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
            },
            child: Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
              setState(() {
                _resultsShown = true; // Set the flag to show results
              });
            },
            child: Text('Yes'),
          ),
          
        ],
      );
    },
  );
}
@override
Widget build(BuildContext context) {
  return Scaffold(
     appBar:  AppBar(
        centerTitle: true,
        title: Text('${widget.quizSet.subjectName} (${widget.quizSet.setName})', style: GoogleFonts.poppins()),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back),
        ),
        
      ),
    body: Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            itemCount: _questions.length,
            itemBuilder: (context, index) {
              final question = _questions[index];

              // Create a list of options for display
              final options = question.options.entries
                  .map((entry) => {
                        'key': entry.key,
                        'value': entry.value,
                      })
                  .toList();

              return Card(
                elevation: 5, // Add shadow to the card
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Question ${index + 1}: ${question.question}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      SizedBox(height: 8.0),
                      ...options.map((option) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(option['value']!, style: TextStyle(fontSize: 16)),
                          leading: Radio<String>(
                            value: option['key']!,
                            groupValue: _userAnswers[question.id],
                            onChanged: _resultsShown
                                ? null  // Disable Radio button if results are shown
                                : (value) {
                                    setState(() {
                                      _userAnswers[question.id] = value;
                                    });
                                  },
                          ),
                        );
                      }).toList(),
                      if (_resultsShown)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Your Answer: ${question.options[_userAnswers[question.id]] ?? 'Not Answered'}', style: TextStyle(color: Colors.orange.shade700, fontSize: 16)),
                              Text('Correct Answer: ${question.options[question.correctAnswer] ?? 'Unknown'}', style: TextStyle(color: Colors.red, fontSize: 16)),
                              Text('Correct: ${_answerCorrectness[question.id] == true ? 'Yes' : 'No'}', style: TextStyle(color: Colors.green, fontSize: 16)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_resultsShown)
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.orange[50], // Background color for score display
            child: Center(
              child: Text(
                'Total Score: $_totalScore/${_questions.length}',
                style: GoogleFonts.openSans(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade700),
              ),
            ),
          ),
        SizedBox(height: 16.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              padding: EdgeInsets.symmetric(vertical: 15.0),
              elevation: 5,
            ),
            onPressed: _submitQuiz,
            child: Padding(
              padding: const EdgeInsets.only(right: 8,left: 8),
              child: Text('Submit', style: TextStyle(fontSize: 14)),
            ),
          ),
        ),
        SizedBox(height: 16.0),
      ],
    ),
    floatingActionButton: FloatingActionButton(
        onPressed: (){
          Navigator.push(context, MaterialPageRoute(builder: (context)=>RobotChatPage()));
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
class Question {
  final String id;
  final String question;
  final Map<String, String> options; // Ensure options is of type Map<String, String>
  final String correctAnswer;

  Question({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswer,
  });
}
