import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_education/models/Teachers.dart';
import 'package:my_education/screens/create_pastyear.dart';
import 'package:my_education/screens/home_page.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';

class QuizPastYearPage extends StatefulWidget {
  @override
  _QuizPastYearPageState createState() => _QuizPastYearPageState();
}

class _QuizPastYearPageState extends State<QuizPastYearPage> {
  final DatabaseReference _pastYearRef = FirebaseDatabase.instance.ref().child('pastYear');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<String> categories = [];
  List<String> years = [];
  List<String> subjects = [];
  
  String? selectedCategory;
  String? selectedYear;
  String? selectedSubject;
  
  List<Map<String, dynamic>> pastYearsData = [];

  @override
  void initState() {
    super.initState();
    _fetchPastYearData();
  }

  Future<void> _fetchPastYearData() async {
    try {
      DataSnapshot snapshot = await _pastYearRef.get();
      if (snapshot.exists) {
        Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;

        Set<String> fetchedCategories = {};
        Set<String> fetchedYears = {};
        Set<String> fetchedSubjects = {};

        List<Map<String, dynamic>> fetchedData = [];

        data.forEach((key, value) {
          Map<dynamic, dynamic> pastYearData = value as Map<dynamic, dynamic>;

          String category = pastYearData['category'] ?? 'Unknown';
          String year = pastYearData['year'] ?? 'Unknown';
          String subject = pastYearData['subject'] ?? 'Unknown';
          bool approve = pastYearData['approve'] ?? false;

          if (approve) {
            fetchedCategories.add(category);
            fetchedYears.add(year);
            fetchedSubjects.add(subject);

            fetchedData.add({
              'category': category,
              'year': year,
              'subject': subject,
              'filePath': pastYearData['filePath'],
              'provider': pastYearData['provider'],
            });
          }
        });

        setState(() {
          categories = fetchedCategories.toList();
          years = fetchedYears.toList();
          subjects = fetchedSubjects.toList();
          pastYearsData = fetchedData;
        });
      } else {
        print('No data found.');
      }
    } catch (e) {
      print('Error fetching data: $e');
    }
  }



Future<String> downloadPdf(String url) async {
  final response = await http.get(Uri.parse(url));
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/temp.pdf');
  await file.writeAsBytes(response.bodyBytes);
  return file.path;
}
  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredData = pastYearsData.where((data) {
      return (selectedCategory == null || data['category'] == selectedCategory) &&
          (selectedYear == null || data['year'] == selectedYear) &&
          (selectedSubject == null || data['subject'] == selectedSubject);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Past Year Questions', style: GoogleFonts.poppins()),
        leading: IconButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context)=>HomePage(Teacher(name: '', university: '', imageAsset: '', rating: 0.0, reviews: 0))));
          },
          icon: Icon(Icons.arrow_back),
        ),
        actions: [IconButton(onPressed: (){
         Navigator.push(
                              context, MaterialPageRoute(builder: (context) => PastYearPage()));
        }, icon: Icon(Icons.add))],
      ),
      body: Column(
        children: [
          SizedBox(height: 16),
          _buildFilterButtons('Categories', categories, selectedCategory, (value) {
            setState(() {
              selectedCategory = value;
            });
          }),
          _buildFilterButtons('Years', years, selectedYear, (value) {
            setState(() {
              selectedYear = value;
            });
          }),
          _buildFilterButtons('Subjects', subjects, selectedSubject, (value) {
            setState(() {
              selectedSubject = value;
            });
          }),
          SizedBox(height: 16),
        Expanded(
  child: filteredData.isEmpty
      ? Center(
          child: Text(
            'No document found', // If no document is found, show this message
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        )
      : ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: filteredData.length,
          itemBuilder: (context, index) {
            Map<String, dynamic> pastYear = filteredData[index];
            return PastYearCard(pastYear: pastYear);
          },
        ),
)


        ],
      ),
    );
  }

  Widget _buildFilterButtons(String title, List<String> items, String? selectedItem, Function(String?) onSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(width: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ChoiceChip(
                      label: Text(item),
                      selected: selectedItem == item,
                      onSelected: (isSelected) {
                        onSelected(isSelected ? item : null);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class PastYearCard extends StatelessWidget {
  final Map<String, dynamic> pastYear;

  PastYearCard({required this.pastYear});

    Future<void> _launchURL(String url) async {
  try {
    final Uri uri = Uri.parse(url);
     await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    print('Error: $e');
  }
}

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
              '${pastYear['subject']} - ${pastYear['year']}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Category: ${pastYear['category']}'),
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
                  _launchURL(pastYear['filePath']);
                  print('Open file: ${pastYear['filePath']}');
                },
                child: Text('Download File'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/*class PDFScreen extends StatelessWidget {
  final String path;

  PDFScreen({required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Past Year Questions', style: GoogleFonts.poppins(color: Colors.white)),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: PDFView(
        filePath: path,
      ),
    );
  }*/

