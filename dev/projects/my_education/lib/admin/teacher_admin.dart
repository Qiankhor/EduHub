import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_education/admin/pastyear_admin.dart';
import 'package:my_education/admin/settings_admin.dart';
import 'package:my_education/services/chat_service.dart';
import 'package:photo_view/photo_view.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class TeacherAdminPage extends StatefulWidget {
  @override
  _TeacherAdminPageState createState() => _TeacherAdminPageState();
}

class _TeacherAdminPageState extends State<TeacherAdminPage> {
  final DatabaseReference _teacherInfoRef = FirebaseDatabase.instance.ref().child('tutorInfo');
   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> promotionalEventData = [];
  List<String> deviceTokens = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTeacherInfoData();
  }

  Future<void> _fetchTeacherInfoData() async {
  try {
    DataSnapshot snapshot = await _teacherInfoRef.get();
    if (snapshot.exists) {
      Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      
      // Check if widget is still mounted before calling setState
      if (mounted) {
        setState(() {
          promotionalEventData = data.entries
              .map((entry) => {
                    'key': entry.key,
                    ...Map<String, dynamic>.from(entry.value as Map<dynamic, dynamic>)
                  })
              .where((item) => item['approve'] == false)
              .toList();
          isLoading = false;
        });
      }
    } else {
      print('No teacherInfo data found.');
      if (mounted) {
        setState(() {
          promotionalEventData = [];
          isLoading = false;
        });
      }
    }
  } catch (e) {
    print('Error fetching teacherInfo data: $e');
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }
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
Future<void> _removeEvent(String key, String providerId, Map<String, dynamic> item) async {
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
            Text('Are you sure you want to reject this tutor? This action cannot be undone.'),
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

      // Remove the tutor data from the Realtime Database
      await _teacherInfoRef.child(key).remove();

      // Send detailed rejection message to the provider
      await _sendRejectionMessage(providerId, reason, item);

      setState(() {
        // Refresh data after deletion
        _fetchTeacherInfoData();
      });
    } catch (e) {
      print('Error removing tutor: $e');
    }
    Navigator.of(context).pop();
  }
}
Future<void> _sendRejectionMessage(String providerId, String reason, Map<String, dynamic> item) async {
  try {
    // Fetch the provider's name and send the chat message
    String providerName = await _getProviderName(providerId);

    // Prepare a detailed rejection message
    String message = '''
Your submission of the tutor has been rejected.

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


  Future<String> _getProviderName(String providerId) async {
    try {
      DocumentSnapshot providerSnapshot = await _firestore.collection('users').doc(providerId).get();
      if (providerSnapshot.exists) {
        Map<String, dynamic>? providerData = providerSnapshot.data() as Map<String, dynamic>?;
        return providerData?['fullName'] ?? 'Unknown';
      } else {
        return 'Unknown';
      }
    } catch (e) {
      print('Error fetching provider name: $e');
      return 'Unknown';
    }
  }

  Future<void> _approveEvent(String key, String providerId, Map<String, dynamic> item) async {
    // Show confirmation dialog
    bool? confirmApproval = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Approval'),
          content: Text('Are you sure you want to approve this tutor?'),
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
      await _teacherInfoRef.child(key).update({'approve': true});
      await _sendApprovalMessage(providerId, item);
      DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(providerId);
    
   
      setState(() {
        // Refresh data
        _fetchTeacherInfoData();
      });
    } catch (e) {
      print('Error approving tutor: $e');
    }
  Navigator.of(context).pop();
}
  }
  Future<void> _sendApprovalMessage(String providerId, Map<String, dynamic> item) async {
  try {
    // Fetch the provider's name
    String providerName = await _getProviderName(providerId);
    _updateTeacherInfo(item['name'],providerId,item['imagePath']);
    // Prepare a detailed approval message
    String message = '''
Congratulations! Your submission of the tutor has been approved.

Additionally, you may now proceed with registering the courses you wish to share.
''';

    // Use your ChatService to send the message to the provider
    ChatService chatService = ChatService();
    await chatService.sendMessage(providerId, message);
  } catch (e) {
    print('Error sending approval message: $e');
  }
}
Future<void> _updateTeacherInfo(String name, String userId,String imagePath) async {
  try {
    await _firestore.collection('users').doc(userId).update({
      'profilePic':imagePath,
      'userType':'Tutor',
      'fullName':name,
    });
    print('Tutor info updated successfully.');
  } catch (e) {
    print('Failed to update tutor info: $e');
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
     appBar: AppBar(
        centerTitle: true,
        title: Text('Tutor Information', style: GoogleFonts.poppins()),
        leading: IconButton(
          onPressed: () {
           Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back,),
        ),
      ),
        body: isLoading // Check loading state first
          ? Center(child: CircularProgressIndicator())
          : promotionalEventData!.isEmpty // If loading is complete, check if data is empty
              ? Center(
                  child: Text(
                    'No tutor data found.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              :ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: promotionalEventData.length,
        itemBuilder: (context, index) {
          var item = promotionalEventData[index];
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
          // Display the image if URL is provided
         GestureDetector(
  onTap: () {
    _showImageDialog(context,item['imagePath']);
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

          SizedBox(height: 8),
          Text(
            item['name'] ?? 'Unknown tutor',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF171A1F),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Education level: ${item['educationLevel'] ?? 'Unknown'}',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w400,
              fontSize: 15,
              color: Color(0xFF171A1F),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Year of Experience: ${item['year'] ?? 'Unknown'}',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w400,
              fontSize: 15,
              color: Color(0xFF171A1F),
            ),
          ),
           SizedBox(height: 4),
          Text(
            'Date of Birth: ${item['dob'] ?? 'Unknown'}',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w400,
              fontSize: 15,
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
              _buildActionButton('Reject', Colors.red,(){
                  _removeEvent(item['key'],item['provider'],item);
              }
              ),
              
              _buildActionButton('Approve', Colors.green, () {
                _approveEvent(item['key'],item['provider'],item);
              }),
              _buildActionButton('View', Colors.blue, () {
                _openPDF(context,item['filePath'] ?? '');
              }),
            ],
          ),
        ],
      ),
    ),
  );


  }

  ElevatedButton _buildActionButton(String label, Color color, [VoidCallback? onPressed]) {
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
