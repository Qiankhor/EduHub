import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_education/models/Teachers.dart';
import 'package:my_education/screens/create_survey.dart';
import 'package:my_education/screens/home_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart'; 

class SurveyPage extends StatefulWidget {
  @override
  _SurveyPageState createState() => _SurveyPageState();
}

class _SurveyPageState extends State<SurveyPage> {
  final DatabaseReference _surveyRef = FirebaseDatabase.instance.ref().child('survey');
  List<Map<String, dynamic>> surveys = [];

  @override
  void initState() {
    super.initState();
    _fetchSurveyData();
  }

  Future<void> _fetchSurveyData() async {
    try {
      DataSnapshot snapshot = await _surveyRef.get();
      if (snapshot.exists) {
        Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> fetchedSurveys = [];

        data.forEach((key, value) {
          Map<dynamic, dynamic> surveyData = value as Map<dynamic, dynamic>;

          bool approve = surveyData['approve'] ?? false;
          if (approve) {
            fetchedSurveys.add({
              'id':surveyData['id'] ?? 'Unknown',
              'theme': surveyData['surveyTheme'] ?? 'Unknown',
              'audience': surveyData['targetAudience'] ?? 'Unknown',
              'url': surveyData['URL'],
              'provider': surveyData['provider'] ?? 'Unknown',
            });
          }
        });

        setState(() {
          surveys = fetchedSurveys;
        });
      } else {
        print('No survey data found.');
      }
    } catch (e) {
      print('Error fetching survey data: $e');
    }
  }

  Future<void> _launchSurveyURL(String url) async {
      try {
    final Uri uri = Uri.parse(url);
     await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    print('Error: $e');
  }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
       appBar: AppBar(
        centerTitle: true,
        title: Text('Survey',style: GoogleFonts.poppins(),),
       leading: IconButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context)=>HomePage(Teacher(name: '', university: '', imageAsset: '', rating: 0.0, reviews: 0))));
          },
          icon: Icon(Icons.arrow_back),
        ),
        actions: [IconButton(onPressed: (){
         Navigator.push(
                              context, MaterialPageRoute(builder: (context) => CreateSurveyPage()));
        }, icon: Icon(Icons.add))],
      ),
      body: surveys.isEmpty
          ? Center(
            child: Text(
              'No surveys available.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          )
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: surveys.length,
              itemBuilder: (context, index) {
                Map<String, dynamic> survey = surveys[index];
                return SurveyCard(survey: survey, onOpenUrl: _launchSurveyURL);
              },
            ),
    );
  }
}

class SurveyCard extends StatefulWidget {
  final Map<String, dynamic> survey;
  final Function(String) onOpenUrl;

  SurveyCard({required this.survey, required this.onOpenUrl});

  @override
  _SurveyCardState createState() => _SurveyCardState();
}

class _SurveyCardState extends State<SurveyCard> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isUploading = false; // To manage upload state

  Future<void> selectProof() async {
    // Pick image from gallery or camera
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> submitProof() async {
    if (_selectedImage == null) return;

    setState(() {
      _isUploading = true; // Show loading state
    });

    // Upload the image to Firebase Storage
    String? downloadUrl = await _uploadImageToStorage(_selectedImage!);

    if (downloadUrl != null) {
      // Store the proof URL under the 'proof' node in Firebase Realtime Database
      await _saveProofToDatabase(downloadUrl);
      setState(() {
        _selectedImage = null; // Clear image after submission
        _isUploading = false; // End loading state
      });
    } else {
      print('Image upload failed');
      setState(() {
        _isUploading = false; // End loading state if upload fails
      });
    }
  }

  Future<String?> _uploadImageToStorage(File imageFile) async {
    try {
      // Create a unique file name
      String fileName = 'proof_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = FirebaseStorage.instanceFor(
                              bucket: "myeducation-865f1.appspot.com"
                            ).ref().child('proofs/${DateTime.now().toIso8601String()}');
      
      // Upload the file
      UploadTask uploadTask = storageRef.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;

      // Get the download URL
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }
Future<void> _saveProofToDatabase(String downloadUrl) async {
  try {
    // Get the current user ID from Firebase Authentication
    User? currentUser = FirebaseAuth.instance.currentUser;
    String? userId = currentUser?.uid;

    if (userId == null) {
      print('Error: User is not logged in');
      return;
    }

    String? surveyId = widget.survey['id'] as String?;

    if (surveyId == null) {
      print('Error: Survey ID is null');
      return;
    }

    // Reference to the 'proof' node under the survey
// 获取 Firebase Database 参考
DatabaseReference proofRef = FirebaseDatabase.instance
    .ref()
    .child('survey')
    .child(surveyId)
    .child('proof');

// 使用 push() 生成一个新的 key
DatabaseReference newProofRef = proofRef.push();

// 获取生成的 key
String proofKey = newProofRef.key ?? '';

// 将数据和 key 一起保存到数据库
await newProofRef.set({
  'id': proofKey,  // 保存生成的 key 到 'id' 节点
  'imageUrl': downloadUrl,
  'provider': userId,  // 保存用户 ID
});


    print('Proof submitted successfully');
  } catch (e) {
    print('Error saving proof: $e');
  }
}


  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Theme: ${widget.survey['theme']}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Target Audience: ${widget.survey['audience']}'),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  onPressed: () => widget.onOpenUrl(widget.survey['url']),
                  child: Text('Open Survey'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  onPressed: () => selectProof(),
                  child: Text('Pick Proof'),
                ),
              ],
            ),
            if (_selectedImage != null)
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Image.file(_selectedImage!, height: 100),
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    onPressed: _isUploading ? null : submitProof, // Disable if uploading
                    child: _isUploading 
                      ? CircularProgressIndicator(color: Colors.white) 
                      : Text('Submit Proof'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
