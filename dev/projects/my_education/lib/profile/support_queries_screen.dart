import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:googleapis/vision/v1.dart' as vision;
import 'package:http/http.dart' as http; // HTTP package for sending requests
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SupportQueriesScreen extends StatefulWidget {
  @override
  State<SupportQueriesScreen> createState() => _SupportQueriesScreenState();
}

class _SupportQueriesScreenState extends State<SupportQueriesScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedSupportType;
  bool _isSubmitting = false;
  String? _evidenceImageUrl;
  final ImagePicker _picker = ImagePicker();

  final List<String> _supportTypes = ['Report issue', 'Feedback', 'Query'];

  /// Upload File to Express Server
  Future<void> _pickAndUploadEvidence() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image == null) {
      Fluttertoast.showToast(
        msg: "No file selected.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      return;
    }

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.2.2:5000/evidence'),
      );

      // Attach the selected file
      var evidenceFile =
          await http.MultipartFile.fromPath('evidenceImage', image.path);
      request.files.add(evidenceFile);

      // Send the request
      var response = await request.send();

      if (response.statusCode == 200) {
        // Parse the response
        var responseData = await http.Response.fromStream(response);
        var data = jsonDecode(responseData.body);

        if (data['imageUrl'] != null) {
          setState(() {
            _evidenceImageUrl =
                data['imageUrl']; // Update the state with the image URL
          });

          Fluttertoast.showToast(
            msg: "File uploaded successfully.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
        } else {
          throw Exception('Server did not return an image URL.');
        }
      } else {
        throw Exception(
            'Failed to upload file with status: ${response.statusCode}');
      }
    } catch (e) {
      print("Error uploading file: $e");
      Fluttertoast.showToast(
        msg: "Failed to upload file: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  /// Submit Support Query
  Future<void> _submitSupportQuery() async {
    if (_selectedSupportType == null || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Get the current user's ID
      final userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('User not authenticated. Please login.')),
        );
        return;
      }

      // If the selected support type requires evidence (not "Feedback" or "Query")
      if (_selectedSupportType != 'Feedback' &&
          _selectedSupportType != 'Query') {
        if (_evidenceImageUrl == null) {
          // Pick and upload the evidence only if the type requires it
          final XFile? image =
              await _picker.pickImage(source: ImageSource.gallery);

          if (image == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No evidence image selected.')),
            );
            return;
          }

          // Upload the evidence file to the server
          var request = http.MultipartRequest(
            'POST',
            Uri.parse(
                'http://10.0.2.2:5000/evidence'), // Change to your server's evidence upload URL
          );

          var evidenceFile =
              await http.MultipartFile.fromPath('evidenceImage', image.path);
          request.files.add(evidenceFile);

          var response = await request.send();

          if (response.statusCode == 200) {
            var responseData = await http.Response.fromStream(response);
            var data = jsonDecode(responseData.body);

            if (data['imageUrl'] != null) {
              setState(() {
                _evidenceImageUrl =
                    data['imageUrl']; // Update the state with the image URL
              });
            } else {
              throw Exception('Server did not return an image URL.');
            }
          } else {
            throw Exception(
                'Failed to upload file with status: ${response.statusCode}');
          }
        }
      }

      // Save to Firestore
      await FirebaseFirestore.instance.collection('support_queries').add({
        'type': _selectedSupportType,
        'description': _descriptionController.text,
        'fileUrl':
            _evidenceImageUrl, // Store the file URL received from the server (or null)
        'submittedAt': FieldValue.serverTimestamp(),
        'userId': userId, // Store the current user's ID
      });

      // Success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support query submitted successfully!')),
      );

      // Reset form
      _descriptionController.clear();
      setState(() {
        _selectedSupportType = null;
        _evidenceImageUrl = null;
      });
    } catch (e) {
      print('Error submitting support query: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit support query.')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Support & Queries'),
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Type of Support', style: TextStyle(fontSize: 16)),
            DropdownButton<String>(
              value: _selectedSupportType,
              hint: const Text('Select support type'),
              isExpanded: true,
              items: _supportTypes
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSupportType = value;
                });
              },
            ),
            const SizedBox(height: 16),
            const Text('Description', style: TextStyle(fontSize: 16)),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Write about your problem...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Evidence', style: TextStyle(fontSize: 16)),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _pickAndUploadEvidence,
              child: Text(_evidenceImageUrl == null
                  ? 'Upload Evidence'
                  : 'Evidence Uploaded'),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitSupportQuery,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
