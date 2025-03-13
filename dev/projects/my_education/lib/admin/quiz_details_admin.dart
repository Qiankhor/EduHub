import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class QuizSetDetailPage extends StatelessWidget {
  final String categoryName;
  final String subjectName;
  final String setName;
  final Map<dynamic, dynamic> setData;

  QuizSetDetailPage({required this.categoryName,required this.subjectName, required this.setName, required this.setData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '$subjectName ($setName)',
          style: GoogleFonts.poppins(),
        ),
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: setData.length,
        itemBuilder: (context, index) {
          String questionKey = setData.keys.elementAt(index);
          var questionData = setData[questionKey];

          // Skip the provider key in the data
          if (questionKey == 'provider') {
            return SizedBox.shrink();
          }

          return Container(
  width: double.infinity, // 使 Container 宽度填满父级
  child: questionData is Map && questionData.containsKey('question') 
    ? Card(
        margin: EdgeInsets.only(bottom: 20), // 确保没有额外的外边距
        child: Padding(
          padding: const EdgeInsets.all(16.0), // Card 内部填充
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Question: ${questionData['question']}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              if (questionData.containsKey('option1'))
                Text('Option 1: ${questionData['option1']}'),
              if (questionData.containsKey('option2'))
                Text('Option 2: ${questionData['option2']}'),
              if (questionData.containsKey('option3'))
                Text('Option 3: ${questionData['option3']}'),
              SizedBox(height: 8),
              if (questionData.containsKey('correctAnswer'))
                Text(
                  'Correct Answer: ${questionData['correctAnswer']}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
            ],
          ),
        ),
      )
    : SizedBox.shrink(), // 如果 questionData 无效，则返回一个空的 SizedBox
);


        },
      ),
    );
  }
}
