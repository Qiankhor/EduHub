import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

class InchatOnlineLearningResourcesScreen extends StatefulWidget {
  final String chatId;
  final bool isCurrentUserTutor;

  const InchatOnlineLearningResourcesScreen({
    super.key,
    required this.chatId,
    required this.isCurrentUserTutor,
  });

  @override
  State<InchatOnlineLearningResourcesScreen> createState() =>
      _InchatOnlineLearningResourcesScreenState();
}

class _InchatOnlineLearningResourcesScreenState
    extends State<InchatOnlineLearningResourcesScreen> {
  String? subject;
  List<LearningMaterial> learningMaterials = []; // Changed to use custom class
  bool isCurrentUserTutor = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchSubjectAndMaterials();
    _checkIfUserIsTutor();
  }

  // Define a class to hold the learning material data

  Future<void> _checkIfUserIsTutor() async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final role = userDoc.data()?['role'];
        setState(() {
          isCurrentUserTutor = role == 'Tutor';
        });
      }
    } catch (e) {
      print("Error checking user role: $e");
    }
  }

  Future<void> _fetchSubjectAndMaterials() async {
    try {
      final tutorId = FirebaseAuth.instance.currentUser!.uid;
      final qualificationDoc = await FirebaseFirestore.instance
          .collection('qualifications')
          .doc(tutorId)
          .get();

      if (qualificationDoc.exists) {
        setState(() {
          subject = qualificationDoc.data()?['subject'] ?? 'Unknown Subject';
        });
      }

      final learningMaterialsSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('learning_material')
          .get();

      final materials = learningMaterialsSnapshot.docs
          .map((doc) => LearningMaterial.fromMap(doc.data()))
          .toList();

      setState(() {
        learningMaterials = materials;
      });
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  Future<void> _uploadPdf() async {
    try {
      if (subject == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Subject not available. Cannot upload PDF.")),
        );
        return;
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final pdfPath = result.files.first.path!;
        final fileName = result.files.first.name;

        setState(() {
          isLoading = true;
        });

        final storageRef = FirebaseStorage.instance
            .ref()
            .child('learning_materials')
            .child(subject!)
            .child('$fileName');

        final uploadTask = storageRef.putFile(File(pdfPath));
        final snapshot = await uploadTask;
        final fileUrl = await snapshot.ref.getDownloadURL();

        final chatDoc =
            FirebaseFirestore.instance.collection('chats').doc(widget.chatId);

        final learningMaterialDoc =
            chatDoc.collection('learning_material').doc(subject);

        await learningMaterialDoc.set(
          {
            'subject': subject,
            'pdf': FieldValue.arrayUnion([fileUrl]),
          },
          SetOptions(merge: true),
        );

        final chatSnapshot = await chatDoc.get();
        final participants =
            List<String>.from(chatSnapshot.data()?['participants'] ?? []);

        final userId = FirebaseAuth.instance.currentUser!.uid;
        final studentId =
            participants.firstWhere((id) => id != userId, orElse: () => '');

        if (studentId.isNotEmpty) {
          final userDoc =
              FirebaseFirestore.instance.collection('users').doc(studentId);

          await userDoc.collection('learning_materials').doc(subject).set(
            {
              'subject': subject,
              'pdf': FieldValue.arrayUnion([fileUrl]),
            },
            SetOptions(merge: true),
          );
        }

        setState(() {
          bool exists = false;
          for (var material in learningMaterials) {
            if (material.pdfList.contains(fileUrl)) {
              exists = true;
              break;
            }
          }

          if (!exists) {
            if (learningMaterials.isEmpty) {
              learningMaterials.add(LearningMaterial(pdfList: [fileUrl]));
            } else {
              learningMaterials[0].pdfList.add(fileUrl);
            }
          }

          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("PDF uploaded successfully")),
        );
      }
    } catch (e) {
      print('Error uploading PDF: $e');
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading PDF: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Learning Materials"),
      ),
      body: learningMaterials.isEmpty
          ? const Center(child: Text("No learning materials available."))
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListView.builder(
                itemCount: learningMaterials.length,
                itemBuilder: (context, index) {
                  final material = learningMaterials[index];
                  final pdfList = material.pdfList;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio:
                              1, // Adjusted for better text display
                        ),
                        itemCount: pdfList.length,
                        itemBuilder: (context, i) {
                          final pdfUrl = pdfList[i];
                          final fileName = extractFileName(
                              pdfUrl); // Ensure proper filename extraction

                          return Card(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 4,
                            child: InkWell(
                              onTap: () async {
                                if (await canLaunch(pdfUrl)) {
                                  await launch(pdfUrl);
                                } else {
                                  print("Could not launch $pdfUrl");
                                }
                              },
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.picture_as_pdf,
                                    color: Colors.red,
                                    size: 50,
                                  ),
                                  const SizedBox(
                                      height:
                                          8), // Adds spacing between icon and text
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    child: Text(
                                      fileName,
                                      textAlign: TextAlign.center,
                                      maxLines:
                                          2, // Limit to 2 lines to avoid overflow
                                      overflow: TextOverflow
                                          .ellipsis, // Show "..." if too long
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
      floatingActionButton: isCurrentUserTutor
          ? FloatingActionButton(
              onPressed: _uploadPdf,
              backgroundColor: Colors.white,
              child: const Icon(
                Icons.add,
                color: Colors.deepPurple,
              ),
            )
          : null,
    );
  }

  String extractFileName(String pdfUrl) {
    String fullFileName =
        Uri.parse(pdfUrl).pathSegments.last; // Extract last segment

    // Remove any prefix before the actual filename (e.g., "learning_materials/Mathematics/filename.pdf")
    if (fullFileName.contains('/')) {
      fullFileName = fullFileName.split('/').last;
    }

    return fullFileName;
  }
}

class LearningMaterial {
  final List<String> pdfList;

  LearningMaterial({required this.pdfList});

  factory LearningMaterial.fromMap(Map<String, dynamic> map) {
    return LearningMaterial(
      pdfList: (map['pdf'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pdf': pdfList,
    };
  }
}
