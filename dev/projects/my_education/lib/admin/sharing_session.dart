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
import 'package:photo_view/photo_view.dart';

class SharingSessionPageAdmin extends StatefulWidget {
  @override
  _SharingSessionPageAdminState createState() =>
      _SharingSessionPageAdminState();
}

class _SharingSessionPageAdminState extends State<SharingSessionPageAdmin> {
  final DatabaseReference _sharingRef =
      FirebaseDatabase.instance.ref().child('sharing');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> sharingData = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSharingData();
  }

  Future<void> _fetchSharingData() async {
    try {
      DataSnapshot snapshot = await _sharingRef.get();
      if (snapshot.exists) {
        Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          sharingData = data.entries
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
        print('No sharing data found.');
        setState(() {
          sharingData = [];
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching sharing data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _removeClass(
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
                  'Are you sure you want to reject this sharing session? This action cannot be undone.'),
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

        // Remove the sharing data from the Realtime Database
        await _sharingRef.child(key).remove();

        // Send detailed rejection message to the provider
        await _sendRejectionMessage(providerId, reason, item);

        DocumentReference userRef =
            FirebaseFirestore.instance.collection('users').doc(providerId);

        setState(() {
          // Refresh data after deletion
          _fetchSharingData();
        });
      } catch (e) {
        print('Error removing sharing: $e');
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
Your submission of the sharing session of $item['name'] on ${item['date']} from ${item['startTime']} has been rejected.

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

  Future<void> _approveSharing(
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
        await _sharingRef.child(key).update({'approve': true});
        await FirebaseFirestore.instance
            .collection('users')
            .doc(providerId)
            .update({
          'createdSessions': FieldValue.arrayUnion([key])
        });
        await _sendApprovalMessage(providerId, item);
        setState(() {
          // Refresh data
          _fetchSharingData();
        });
      } catch (e) {
        print('Error approving sharing: $e');
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
Congratulations! Your sharing session submission has been approved. It is scheduled for ${item['date']} from ${item['startTime']} to ${item['endTime']} under the ${item['name'] ?? 'Unknown Category'} .
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
        title: Text('Sharing Sessions', style: GoogleFonts.poppins()),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back),
        ),
      ),
      body: isLoading // Check loading state first
          ? Center(child: CircularProgressIndicator())
          : sharingData
                  .isEmpty // If loading is complete, check if data is empty
              ? Center(
                  child: Text(
                    'No sharing data found.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: sharingData.length,
                  itemBuilder: (context, index) {
                    var item = sharingData[index];
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

  void _showImageDialog(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: PhotoView(
            imageProvider: NetworkImage(imagePath),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
            backgroundDecoration: BoxDecoration(
              color: Colors.transparent,
            ),
          ),
        );
      },
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
            GestureDetector(
              onTap: () {
                _showImageDialog(context, item['imagePath']);
              },
              child: item['imagePath'] != null && item['imagePath'].isNotEmpty
                  ? Container(
                      height: 150, // Adjust the height as needed
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(item['imagePath']),
                          fit: BoxFit.contain, // Adjust fit as needed
                        ),
                      ),
                    )
                  : Container(),
            ),
            Text(
              item['name'] ?? 'Unknown Category',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF171A1F),
              ),
            ),
            SizedBox(height: 4),
            Text(
              "Date: " + item['date'],
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
              "Time: " + item['startTime'] + " - " + item['endTime'],
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 14,
                color: Color(0xFF171A1F),
              ),
            ),
            SizedBox(height: 4),
            Text(
              "Description: " + item['description'],
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
                  _removeClass(item['key'], item['provider'], item);
                }),
                _buildActionButton('Approve', Colors.green, () {
                  _approveSharing(item['key'], item['provider'], item);
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
