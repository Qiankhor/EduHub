import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_education/admin/settings_admin.dart';
import 'package:my_education/services/chat_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:platform/platform.dart';

class PromotionalEventPage extends StatefulWidget {
  @override
  _PromotionalEventPageState createState() => _PromotionalEventPageState();
}

class _PromotionalEventPageState extends State<PromotionalEventPage> {
  final DatabaseReference _promotionalEventRef =
      FirebaseDatabase.instance.ref().child('promotionalEvent');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> promotionalEventData = [];
  List<String> deviceTokens = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPromotionalEventData();
  }

  Future<void> _fetchPromotionalEventData() async {
    try {
      DataSnapshot snapshot = await _promotionalEventRef.get();
      if (snapshot.exists) {
        Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          promotionalEventData = data.entries
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
        print('No promotionalEvent data found.');
        setState(() {
          promotionalEventData = [];
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching promotionalEvent data: $e');
      setState(() {
        isLoading = false;
      });
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

  Future<void> _removeEvent(
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
                  'Are you sure you want to reject this event? This action cannot be undone.'),
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

        // Remove the event data from the Realtime Database
        await _promotionalEventRef.child(key).remove();

        // Send detailed rejection message to the provider
        await _sendRejectionMessage(providerId, reason, item);

        setState(() {
          // Refresh data after deletion
          _fetchPromotionalEventData();
        });
      } catch (e) {
        print('Error removing event: $e');
      }
      Navigator.of(context).pop();
    }
  }

  Future<void> _sendRejectionMessage(
      String providerId, String reason, Map<String, dynamic> item) async {
    try {
      // Fetch the provider's name and send the chat message
      String providerName = await _getProviderName(providerId);

      DocumentReference userRef =
          FirebaseFirestore.instance.collection('users').doc(providerId);
      CollectionReference transactionRef = userRef.collection('transactions');

// Perform transaction to update points and save history
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(userRef);
        int currentPoints = 0;
        if (snapshot.exists) {
          currentPoints = snapshot['points'] ?? 0;
          transaction.update(userRef, {'points': currentPoints + 100});
        } else {
          transaction.set(userRef, {'points': 100});
        }

        // Create a document reference for the new transaction record
        DocumentReference newTransactionRef =
            transactionRef.doc(); // Generate a new document ID

        // Add the transaction record as part of the transaction
        transaction.set(newTransactionRef, {
          'points': 100,
          'type': 'addition', // or 'deduction' for deductions
          'reason': 'Reject event',
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      // Prepare a detailed rejection message
      String message = '''
Your submission of the event has been rejected.

Details of the event submission:
- Event Name: ${item['eventName'] ?? 'Unknown Event Name'}
- Participation Fee: ${item['participationFee'] ?? 'Participation Fee'}
- Target Group: ${item['targetAudience'] ?? 'Unknown Target Group'}

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

  Future<void> _approveEvent(
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
        await _promotionalEventRef.child(key).update({'approve': true});
        await _sendApprovalMessage(providerId, item);
        List<String> deviceTokens = await _fetchAllUserDeviceTokens();
        await _sendFCMPushNotification(
            deviceTokens, "Hot Event Coming Soon!", "Check It Out Now!");
        setState(() {
          // Refresh data
          _fetchPromotionalEventData();
        });
      } catch (e) {
        print('Error approving survey: $e');
      }
      Navigator.of(context).pop();
    }
  }

  Future<List<String>> _fetchAllUserDeviceTokens() async {
    List<String> deviceTokens = [];

    try {
      // Fetch all users from Firestore
      QuerySnapshot usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();

      for (var doc in usersSnapshot.docs) {
        // Ensure doc.data() is not null
        var data = doc.data() as Map<String,
            dynamic>?; // Casting to Map<String, dynamic> for null-safety

        if (data != null && data.containsKey('deviceToken')) {
          String? token = data['deviceToken'];
          if (token != null && token.isNotEmpty) {
            deviceTokens.add(token);
          }
        }
      }
    } catch (e) {
      print('Error fetching user device tokens: $e');
    }

    return deviceTokens;
  }

  static Future<String> getAccessToken() async {
    final serviceAccountJson = {
      "type": "service_account",
      "project_id": "myeducation-865f1",
      "private_key_id": "66bfa45fd822f49d5c1a954021b6a558f2483854",
      "private_key":
          "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC9VloaN+EQzAxC\nd1VOMYFuRqZPCKMyadxM/DMxMxu7yd9MGmVZ2mViM99uG/2G11yh8q1iBPi0yzZN\nBXWOBFHI8On/78pFPRUZ57SCZ/G7oO6tQQ+IhZWWKZjDp2K7BfLHkK5IKH9eV9EG\nE9UJ1f8e/ud+2BwshN5J0BWy3iDqLg+aj1iaeenaEFkiohtWicFzYC3sS9DX13Tk\n/kEVh5ItCvMdDucUoqZOe0QlPuH3Iox8HHcKkYB4ksyRDQMZpCY3N/1Z5rMJvAIV\nT4uJKGaus764XExT7Mc2MEvMJ1vIM2gWnH/OGAYnkT2ZIyOu0EWteFiwg551Joo1\nExkPofJxAgMBAAECggEAAPjjxE3yzS/N2DY6gfwbPilyD4aVTb9XqWEKDPSZjdUU\nHS6aN3qGVsyUCk6UPN6klZo0VZDxOBg+VoNCsEvTIckj6Hbb07YKaOxEykuI/rXH\nBMZ7k0L28Rl6u0MQv/7zmTgwpU/1uUXFHeCY8W1paC7QQHL3Y3g75HmwMAkrA3M4\nEMZbZBYMLac3vMVMqYZ1aMWQu5hMu0edFHoVK2sRlRfMQ8z+GdXaSMZCqxiKc6tE\nGpzFq7k1B2+M33ea36Cha8lT7zJWoaW4YId/dLluMA1SNH5++Tg5hQZn/PtUlcne\ncT/adBLl0IQ/daMrNgjQusMfzrcOmeS0dhLeoHGsyQKBgQD9wEtIjzqQwsNJEBw5\nem9foOhEDWCJXtwu+F9OkPorshj7t7DrRYW5JP7mGbFOgkuw810k/ZsGbqu+5fx6\nEGTEelGzYg5loVodR6lyvwWLUA6OlAgm6HBS0uQ9hNAgbrcGmKnROhFhaBhmnyuv\nQxtuScaRb1bMWxAXHa7THwMUWQKBgQC/A+q+GdynMmxuM2VbCsayNOykWj6TlC5K\ncFRJJMSguSYRyzirUrH0bN7KXceLWOhMa/3Onwl+IghxNrEcST1d9Zyd5P/4rMAg\nv4TAKxSt7iXM/W+wj95nryPNx3NAWxltGRSM+NHqcAs4PsVYAWoNZflFS1uN7CLF\nCWi5Ghjr2QKBgCj34++6GDWJDGh+bmAlUVf6LaXXFw/2vcvjk9emdo2ZeokhdjH2\nDon+3BygZ00KolfWYuJ3A5F9SsNOdH3sqahDK2+v1C06aMcza7s39hgw+7ivU8Wc\nX44vuGPqToP9/BTXjwtVubqlSNNAvZfVWNdsl9+hPz1NMoLY6wHxDtk5AoGAIVlb\nuIjnX0GMcMkEXxrIigB3eFJRLo7mbhSigoqq0azBmsWyRScQ7q27T/WDiy6gkAci\nrtpRW/YxJyL3VQrsbeUdzOtYTWBLwuvtD2f2Gk/DxcBRqa/UkqGfTKQP2SKOk9+X\nGO2wKJAbRVygM7c7fs9Y7+IyP9sETwZPhFGsHDECgYEAosRLS5o6c3VGY0EX4Laq\n/DASoci2R/lzOgOnwPlgwTCnHasRiwne+PyKpXB/BsWQIphlv/D0Dt06bhE3AhuO\nWGS0F75bT6qpPcK5XE+Vpu8oUjShjETDCUrl/zKWCtL68GlxeJmakx2Uxzfi4su9\nffEqSTZwJORxpCKJD3pTvy8=\n-----END PRIVATE KEY-----\n",
      "client_email": "my-education@myeducation-865f1.iam.gserviceaccount.com",
      "client_id": "111566471348347513301",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url":
          "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url":
          "https://www.googleapis.com/robot/v1/metadata/x509/my-education%40myeducation-865f1.iam.gserviceaccount.com",
      "universe_domain": "googleapis.com"
    };

    List<String> scopes = [
      "https://www.googleapis.com/auth/userinfo.email",
      "https://www.googleapis.com/auth/firebase.database",
      "https://www.googleapis.com/auth/firebase.messaging"
    ];

    http.Client client = await auth.clientViaServiceAccount(
      auth.ServiceAccountCredentials.fromJson(serviceAccountJson),
      scopes,
    );

    auth.AccessCredentials credentials =
        await auth.obtainAccessCredentialsViaServiceAccount(
      auth.ServiceAccountCredentials.fromJson(serviceAccountJson),
      scopes,
      client,
    );
    client.close();

    return credentials.accessToken.data;
  }

  /*Future<void> _sendPushNotification(String title, String message) async {
    bool isHuawei = await isHuaweiDevice();
    try {
      // Fetch all users from Firestore to get their device tokens
      QuerySnapshot usersSnapshot = await _firestore.collection('users').get();
      for (var userDoc in usersSnapshot.docs) {
        String deviceToken = userDoc['deviceToken']; // Make sure this field exists
        if (deviceToken != null && deviceToken.isNotEmpty) {
          // Determine if the device is Huawei
          if (isHuawei) {
            await _sendHMSPushNotification(deviceToken, title, message);
          } else {
            await _sendFCMPushNotification(deviceToken, title, message);
          }
        }
      }
      print("Push notification sent successfully to all users");
    } catch (e) {
      print("Error sending push notification: $e");
    }
  } */
  void checkDevice() async {
    bool huawei = await isHuaweiDevice();
    if (huawei) {
      print('This is a Huawei device.');
    } else {
      print('This is not a Huawei device.');
    }
  }

  Future<bool> isHuaweiDevice() async {
    final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    final Platform platform = LocalPlatform();
    if (platform.isAndroid) {
      final androidInfo = await deviceInfoPlugin.androidInfo;
      // Check if the manufacturer is Huawei
      return androidInfo.manufacturer.toLowerCase() == 'huawei';
    }
    // Add other platform checks if needed
    return false;
  }

  Future<void> _sendHMSPushNotification(
      String deviceToken, String title, String message) async {
    // Your HMS notification sending logic
  }
  Future<void> _sendFCMPushNotification(
      List<String> deviceTokens, String title, String message) async {
    final String serverAccessTokenKey = await getAccessToken();
    String endpointFirebaseCloudMessaging =
        'https://fcm.googleapis.com/v1/projects/myeducation-865f1/messages:send';

    for (String deviceToken in deviceTokens) {
      final Map<String, dynamic> fcmMessage = {
        'message': {
          'token': deviceToken, // 发送到单个设备
          'notification': {
            'title': title,
            'body': message,
          },
        },
      };

      try {
        final http.Response response = await http.post(
          Uri.parse(endpointFirebaseCloudMessaging),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $serverAccessTokenKey',
          },
          body: jsonEncode(fcmMessage),
        );

        if (response.statusCode == 200) {
          print('Notification sent to $deviceToken successfully');
        } else {
          print(
              'Failed to send notification to $deviceToken: ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        print('Error occurred while sending notification to $deviceToken: $e');
      }
    }
  }

  Future<void> _sendApprovalMessage(
      String providerId, Map<String, dynamic> item) async {
    try {
      // Fetch the provider's name
      String providerName = await _getProviderName(providerId);

      // Prepare a detailed approval message
      String message = '''
Congratulations! Your submission of the event has been approved.

Details of the event submission:
- Event Name: ${item['eventName'] ?? 'Unknown Event Name'}
- Participation Fee: ${item['participationFee'] ?? 'Participation Fee'}
- Target Group: ${item['targetAudience'] ?? 'Unknown Target Group'}
''';

      // Use your ChatService to send the message to the provider
      ChatService chatService = ChatService();
      await chatService.sendMessage(providerId, message);
    } catch (e) {
      print('Error sending approval message: $e');
    }
  }

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
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Promotional Events', style: GoogleFonts.poppins()),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back),
        ),
      ),
      body: isLoading // Check loading state first
          ? Center(child: CircularProgressIndicator())
          : promotionalEventData!
                  .isEmpty // If loading is complete, check if data is empty
              ? Center(
                  child: Text(
                    'No promotional event data found.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
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

            SizedBox(height: 8),
            Text(
              item['eventName'] ?? 'Unknown Event',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF171A1F),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Target Audience: ${item['targetAudience'] ?? 'Unknown'}',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w400,
                fontSize: 15,
                color: Color(0xFF171A1F),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Participation Fee: ${item['participationFee'] ?? 'Unknown'}',
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
                _buildActionButton('Reject', Colors.red, () {
                  _removeEvent(item['key'], item['provider'], item);
                }),
                _buildActionButton('Approve', Colors.green, () {
                  _approveEvent(item['key'], item['provider'], item);
                }),
                _buildActionButton('View', Colors.blue, () {
                  _launchURL(item['URL'] ?? '');
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
