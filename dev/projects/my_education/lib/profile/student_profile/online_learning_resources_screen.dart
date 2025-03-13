import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class OnlineLearningResourcesScreen extends StatefulWidget {
  const OnlineLearningResourcesScreen({Key? key}) : super(key: key);

  @override
  State<OnlineLearningResourcesScreen> createState() =>
      _OnlineLearningResourcesScreenState();
}

class _OnlineLearningResourcesScreenState
    extends State<OnlineLearningResourcesScreen> {
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Online Learning Resources"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('learning_materials')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text("No learning materials available."));
          }

          final materials = snapshot.data!.docs;

          // Group the materials by subject
          Map<String, List<String>> groupedMaterials = {};
          for (var doc in materials) {
            final data = doc.data() as Map<String, dynamic>;
            final subject = data['subject'] ?? 'Unknown Subject';
            final pdfList = List<String>.from(data['pdf'] ?? []);
            groupedMaterials.putIfAbsent(subject, () => []).addAll(pdfList);
          }

          return ListView(
            padding: const EdgeInsets.all(8.0),
            children: groupedMaterials.entries.map((entry) {
              final subject = entry.key;
              final pdfList = entry.value;
              return _buildSubjectSection(subject, pdfList);
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildSubjectSection(String subject, List<String> pdfList) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: ExpansionTile(
        title: Text(
          subject,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0),
        ),
        children: pdfList.map((pdfUrl) {
          String fullFileName =
              Uri.parse(pdfUrl).pathSegments.last; // Extract last segment

          if (fullFileName.contains('/')) {
            fullFileName = fullFileName.split('/').last;
          }
          return ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
            title: Text(
              fullFileName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            onTap: () async {
              if (await canLaunch(pdfUrl)) {
                await launch(pdfUrl);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not launch $pdfUrl')),
                );
              }
            },
          );
        }).toList(),
      ),
    );
  }
}
