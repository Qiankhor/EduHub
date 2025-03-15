import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:my_education/admin/settings_admin.dart';
import 'package:my_education/services/chat_service.dart';
import 'package:path_provider/path_provider.dart';

class PastYearPageAdmin extends StatefulWidget {
  @override
  _PastYearPageAdminState createState() => _PastYearPageAdminState();
}

class _PastYearPageAdminState extends State<PastYearPageAdmin> {
  final DatabaseReference _pastYearRef =
      FirebaseDatabase.instance.ref().child('pastYear');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> pastYearData = [];
  bool isLoading = true;

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
        setState(() {
          pastYearData = data.entries
              .map((entry) => {
                    'key': entry.key,
                    ...Map<String, dynamic>.from(
                        entry.value as Map<dynamic, dynamic>)
                  })
              .where((item) => item['approve'] == false)
              .toList();
          isLoading = false;
        });
      } else {
        print('No past year data found.');
        setState(() {
          pastYearData = [];
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching past year data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _removePastYear(
      String key, String providerId, Map<String, dynamic> item) async {
    TextEditingController _reasonController = TextEditingController();

    // Show a dialog to get the rejection reason from the admin
    bool? confirmRemoval = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Rejection'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Are you sure you want to reject this past year? This action cannot be undone.'),
              SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: 'Reason for rejection',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (_reasonController.text.isNotEmpty) {
                  Navigator.of(context).pop(true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Please provide a reason for rejection'),
                  ));
                }
              },
              child: Text('Reject'),
            ),
          ],
        );
      },
    );

    if (confirmRemoval == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false, // 禁止在加载时关闭对话框
          builder: (BuildContext context) {
            return Center(
              child: CircularProgressIndicator(),
            );
          },
        );
        String reason = _reasonController.text;

        // Remove the past year data from the Realtime Database
        await _pastYearRef.child(key).remove();

        // Send detailed rejection message to the provider
        await _sendRejectionMessage(providerId, reason, item);

        setState(() {
          // Refresh data after deletion
          _fetchPastYearData();
        });
      } catch (e) {
        print('Error removing past year: $e');
      }
      Navigator.of(context).pop();
    }
  }

  Future<void> _sendRejectionMessage(
      String providerId, String reason, Map<String, dynamic> item) async {
    try {
      // Fetch the provider's name and send the chat message
      String providerName = await _getProviderName(providerId);

      // Prepare a detailed rejection message
      String message = '''
Your submission of the past year paper has been rejected.

Details of the past year submission:
- Category: ${item['category'] ?? 'Unknown Category'}
- Subject: ${item['subject'] ?? 'Unknown Subject'}
- Year: ${item['year'] ?? 'Unknown Year'}

Reason for rejection:
$reason
''';

      // Use your ChatService to send the message to the provider
      ChatService chatService = ChatService();
      await chatService.sendMessage(providerId, message);
    } catch (e) {
      print('Error sending rejection message: $e');
    }
  }

  Future<void> _openPDF(BuildContext context, String url) async {
    try {
      final path = await downloadPdf(url);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PDFScreen(path: path),
        ),
      );
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<String> downloadPdf(String url) async {
    final response = await http.get(Uri.parse(url));
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/temp.pdf');
    await file.writeAsBytes(response.bodyBytes);
    return file.path;
  }

  Future<void> _approvePastYear(
      String key, String providerId, Map<String, dynamic> item) async {
    // Show confirmation dialog
    bool? confirmApproval = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Approval'),
          content: Text('Are you sure you want to approve this event?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Approve'),
            ),
          ],
        );
      },
    );

    if (confirmApproval == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false, // 禁止在加载时关闭对话框
          builder: (BuildContext context) {
            return Center(
              child: CircularProgressIndicator(),
            );
          },
        );
        // Update the 'approve' field to true in Realtime Database
        await _pastYearRef.child(key).update({'approve': true});
        await _sendApprovalMessage(providerId, item);

        DocumentReference userRef =
            FirebaseFirestore.instance.collection('users').doc(providerId);
        CollectionReference transactionRef = userRef.collection('transactions');

// Perform transaction to update points and save history
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          DocumentSnapshot snapshot = await transaction.get(userRef);
          int currentPoints = 0;
          if (snapshot.exists) {
            currentPoints = snapshot['points'] ?? 0;
            transaction.update(userRef, {'points': currentPoints + 15});
          } else {
            transaction.set(userRef, {'points': 15});
          }

          // Create a document reference for the new transaction record
          DocumentReference newTransactionRef =
              transactionRef.doc(); // Generate a new document ID

          // Add the transaction record as part of the transaction
          transaction.set(newTransactionRef, {
            'points': 15,
            'type': 'addition', // or 'deduction' for deductions
            'reason': 'Distribute pass year',
            'timestamp': FieldValue.serverTimestamp(),
          });
        });

        setState(() {
          // Refresh data
          _fetchPastYearData();
        });
      } catch (e) {
        print('Error approving past year: $e');
      }
      Navigator.of(context).pop();
    }
  }

  Future<void> _sendApprovalMessage(
      String providerId, Map<String, dynamic> item) async {
    try {
      // Fetch the provider's name
      String providerName = await _getProviderName(providerId);

      // Prepare a detailed approval message
      String message = '''
Congratulations! Your submission of the past year paper has been approved.

Details of the past year submission:
- Category: ${item['category'] ?? 'Unknown Category'}
- Subject: ${item['subject'] ?? 'Unknown Subject'}
- Year: ${item['year'] ?? 'Unknown Year'}

Additionally, you have earned 15 points for this approval. Keep up the great work!
''';

      // Use your ChatService to send the message to the provider
      ChatService chatService = ChatService();
      await chatService.sendMessage(providerId, message);
    } catch (e) {
      print('Error sending approval message: $e');
    }
  }

  Future<String> _getProviderName(String providerId) async {
    try {
      DocumentSnapshot providerSnapshot =
          await _firestore.collection('users').doc(providerId).get();
      if (providerSnapshot.exists) {
        Map<String, dynamic>? providerData =
            providerSnapshot.data() as Map<String, dynamic>?;
        return providerData?['fullName'] ?? 'Unknown';
      } else {
        return 'Unknown';
      }
    } catch (e) {
      print('Error fetching provider name: $e');
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Past Year Questions', style: GoogleFonts.poppins()),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back),
        ),
      ),
      body: isLoading // Check loading state first
          ? Center(child: CircularProgressIndicator())
          : pastYearData!
                  .isEmpty // If loading is complete, check if data is empty
              ? Center(
                  child: Text(
                    'No past year data found.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: pastYearData.length,
                  itemBuilder: (context, index) {
                    var item = pastYearData[index];
                    return FutureBuilder<String>(
                      future: _getProviderName(item['provider']),
                      builder: (context, snapshot) {
                        String providerName = snapshot.data ?? 'Loading...';
                        return _buildDataCard(item, providerName);
                      },
                    );
                  },
                ),
    );
  }

  Widget _buildDataCard(Map<String, dynamic> item, String providerName) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['category'] ?? 'Unknown Category',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF171A1F),
              ),
            ),
            SizedBox(height: 4),
            Text(
              "Subject: " + item['subject'],
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 14,
                color: Color(0xFF171A1F),
              ),
            ),
            SizedBox(
              height: 4,
            ),
            Text(
              "Year: " + item['year'],
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 14,
                color: Color(0xFF171A1F),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Provider: $providerName',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w400,
                fontSize: 12,
                color: Color(0xFF9095A0),
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildActionButton('Reject', Colors.red, () {
                  _removePastYear(item['key'], item['provider'], item);
                }),
                _buildActionButton('Approve', Colors.green, () {
                  _approvePastYear(item['key'], item['provider'], item);
                }),
                _buildActionButton('View', Colors.blue, () {
                  _openPDF(context, item['filePath'] ?? '');
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ElevatedButton _buildActionButton(String label, Color color,
      [VoidCallback? onPressed]) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class PDFScreen extends StatelessWidget {
  final String path;

  PDFScreen({required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back),
        ),
      ),
      body: PDFView(
        filePath: path,
      ),
    );
  }
}
