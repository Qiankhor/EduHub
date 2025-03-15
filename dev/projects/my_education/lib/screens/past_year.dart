import 'dart:io';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_education/models/Teachers.dart';
import 'package:my_education/screens/create_pastyear.dart';
import 'package:my_education/screens/home_page.dart';
import 'package:http/http.dart' as http;
import 'package:my_education/screens/pdf_generator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class QuizPastYearPage extends StatefulWidget {
  @override
  _QuizPastYearPageState createState() => _QuizPastYearPageState();
}

class _QuizPastYearPageState extends State<QuizPastYearPage> {
  final DatabaseReference _pastYearRef =
      FirebaseDatabase.instance.ref().child('pastYear');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<String> categories = [];
  List<String> years = [];
  List<String> subjects = [];

  String? selectedCategory;
  String? selectedYear;
  String? selectedSubject;

  List<Map<String, dynamic>> pastYearsData = [];
  bool isLoading = true; // Add loading state

  @override
  void initState() {
    super.initState();
    _fetchPastYearData();
  }

  Future<void> _fetchPastYearData() async {
    setState(() {
      isLoading = true; // Set loading to true when fetching starts
    });

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
          isLoading = false; // Set loading to false after data is fetched
        });
      } else {
        print('No data found.');
        setState(() {
          isLoading = false; // Set loading to false even if no data
        });
      }
    } catch (e) {
      print('Error fetching data: $e');
      setState(() {
        isLoading = false; // Set loading to false if there's an error
      });
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
      return (selectedCategory == null ||
              data['category'] == selectedCategory) &&
          (selectedYear == null || data['year'] == selectedYear) &&
          (selectedSubject == null || data['subject'] == selectedSubject);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Past Year Questions', style: GoogleFonts.poppins()),
        leading: IconButton(
          onPressed: () {
            Navigator.push(
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
                    MaterialPageRoute(builder: (context) => PastYearPage()));
              },
              icon: Icon(Icons.add))
        ],
      ),
      body: Column(
        children: [
          SizedBox(height: 16),
          _buildFilterButtons('Categories', categories, selectedCategory,
              (value) {
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
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.orange.shade700),
                    ),
                  )
                : filteredData.isEmpty
                    ? Center(
                        child: Text(
                          'No document found',
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

  Widget _buildFilterButtons(String title, List<String> items,
      String? selectedItem, Function(String?) onSelected) {
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

// Inside PastYearCard class
  Future<void> _generateAIAnswers(
      BuildContext context, Map<String, dynamic> pastYear) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.orange.shade700),
                ),
                SizedBox(height: 16),
                Text('Generating AI answers...'),
              ],
            ),
          ),
        );
      },
    );

    try {
      // Get AI service
      final aiService = GoogleAIService();

      // Generate AI answers
      final String aiContent = await aiService.generateAnswers(
          pastYear['subject'], pastYear['year'], pastYear['category']);

      // Generate PDF file
      final File pdfFile = await PdfGenerator.generateAnswersPdf(
        subject: pastYear['subject'],
        year: pastYear['year'],
        category: pastYear['category'],
        aiContent: aiContent,
      );

      // Close loading dialog
      Navigator.of(context).pop();

      // Open PDF viewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text(
                  'AI Answers for ${pastYear['subject']} - ${pastYear['year']}'),
              actions: [
                IconButton(
                  icon: Icon(Icons.share),
                  onPressed: () async {
                    try {
                      // Check if file exists
                      final file = File(pdfFile.path);
                      if (await file.exists()) {
                        // Use SharePlatform.instance.shareXFiles for newer versions of share_plus
                        final result = await Share.shareXFiles(
                          [XFile(pdfFile.path)],
                          text:
                              'AI Generated answers for ${pastYear['subject']} - ${pastYear['year']}',
                          subject: 'Past Year Answers',
                        );

                        // Optional: Handle the result
                        if (result.status == ShareResultStatus.success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Shared successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } else {
                        // Show error if file doesn't exist
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('File not found'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } catch (e) {
                      // Show error for any issues
                      print('Share error: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to share: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            body: PDFView(
              filePath: pdfFile.path,
              enableSwipe: true,
              swipeHorizontal: true,
              autoSpacing: false,
              pageFling: false,
              pageSnap: false,
              defaultPage: 0,
              fitPolicy: FitPolicy.BOTH,
              preventLinkNavigation: false,
              onError: (error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $error')),
                );
                debugPrint('Error occurred: $error');
              },
            ),
          ),
        ),
      );
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate AI answers: $e')),
      );
      debugPrint('Error occurred: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
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
            // Wrap buttons in a Column on small screens and Row on larger screens
            LayoutBuilder(
              builder: (context, constraints) {
                // If we have enough width, use a Row
                if (constraints.maxWidth > 300) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
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
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.smart_toy),
                          label: Text('AI Answers'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          onPressed: () {
                            _generateAIAnswers(context, pastYear);
                          },
                        ),
                      ),
                    ],
                  );
                } else {
                  // If the screen is narrow, stack buttons vertically
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
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
                      SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: Icon(Icons.smart_toy),
                        label: Text('AI Answers'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        onPressed: () {
                          _generateAIAnswers(context, pastYear);
                        },
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class GoogleAIService {
  final String _apiKey =
      dotenv.env['GEMINI_API_KEY'] ?? ''; // Ensure it's never null
  final GenerativeModel _model;

  GoogleAIService()
      : _model = GenerativeModel(
          model: 'gemini-1.5-pro',
          apiKey: dotenv.env['GEMINI_API_KEY'] ??
              '', // Handle potential null values
        );
  Future<String> generateAnswers(
      String subject, String year, String category) async {
    try {
      final prompt = """
        Generate answers for $subject past year exam ($year) for $category category.
        Provide comprehensive solutions with step-by-step explanations.
        Format the answers in a clear, structured way suitable for students.
      """;

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text ?? 'No answer generated';
    } catch (e) {
      throw Exception('Failed to generate answers: $e');
    }
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
