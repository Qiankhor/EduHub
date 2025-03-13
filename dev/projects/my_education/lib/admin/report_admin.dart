import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_education/admin/settings_admin.dart';
import 'package:my_education/models/Teachers.dart';
import 'package:my_education/screens/home_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_education/services/chat_service.dart';
import 'package:photo_view/photo_view.dart';

class ReportPage extends StatefulWidget {
  @override
  _ReportPageState createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final DatabaseReference _reportRef = FirebaseDatabase.instance.ref().child('reports');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> surveyData = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  Future<void> _fetchReportData() async {
    try {
      DataSnapshot snapshot = await _reportRef.get();
      if (snapshot.exists) {
        Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          surveyData = data.entries
              .map((entry) => {
                    'key': entry.key,
                    ...Map<String, dynamic>.from(entry.value as Map<dynamic, dynamic>)
                  })
              .toList();
          isLoading = false;
        });
      } else {
        print('No report data found.');
        setState(() {
          surveyData = [];
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching report data: $e');
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
  Future<String> _getName(String id) async {
    try {
      DocumentSnapshot userSnapshot = await _firestore.collection('users').doc(id).get();
      if (userSnapshot.exists) {
        Map<String, dynamic>? userData = userSnapshot.data() as Map<String, dynamic>?;
        return userData?['fullName'] ?? 'Unknown';
      } else {
        return 'Unknown';
      }
    } catch (e) {
      print('Error fetching name: $e');
      return 'Unknown';
    }
  }

Future<void> _approveReport(String key, String providerId, String reportedId, Map<String, dynamic> item) async {
  String reportedUserName = await _getName(reportedId);
  bool? confirmApproval = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Confirm Approval'),
        content: Text('Are you sure you want to block the account of $reportedUserName? They will no longer be able to sell any items on eduMart.'),
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
      // 删除 report 数据
      await _reportRef.child(key).remove();

      // 发送批准消息
      await _sendApprovalMessage(providerId, reportedId, item);

      // 更新 reported 用户的状态为 "block"
      await _firestore.collection('users').doc(reportedId).update({
        'status': 'block',
        'userType': 'student',
      }); 

      // 删除 reported 用户的所有交易
      await _deleteUserTransactions(reportedId);

      // 删除与老师相关的整个 teacherInfo 节点
      await _deleteTeacherInfoByProviderId(reportedId);

      // 刷新报告数据
      setState(() {
        _fetchReportData();
      });
    } catch (e) {
      print('Error approving report: $e');
    }
    Navigator.of(context).pop();
  }
}

Future<void> _deleteTeacherInfoByProviderId(String reportedId) async {
  DatabaseReference teacherRef = FirebaseDatabase.instance.ref('teacherInfo');

  // 查询匹配的 teacherInfo 节点
  DatabaseEvent event = await teacherRef.orderByChild('provider').equalTo(reportedId).once();

  // 检查查询结果
  if (event.snapshot.exists) {
    print('Teacher info found for provider: $reportedId');
    
    // 遍历结果并删除匹配的节点
    for (var childSnapshot in event.snapshot.children) {
      print('Deleting node: ${childSnapshot.key}');
      await teacherRef.child(childSnapshot.key!).remove();
    }
  } else {
    print('No teacher info found for provider: $reportedId');
  }
}

Future<void> _deleteUserTransactions(String reportedUserId) async {
  DatabaseReference transactionsRef = FirebaseDatabase.instance.ref().child('transactions');

  try {
    DataSnapshot snapshot = await transactionsRef.get();
    if (snapshot.exists) {
      Map<dynamic, dynamic> transactions = snapshot.value as Map<dynamic, dynamic>;

      // Find and delete transactions where provider matches reportedUserId
      transactions.forEach((key, transaction) async {
        if (transaction['provider'] == reportedUserId) {
          await transactionsRef.child(key).remove();
          print('Deleted transaction: $key');
        }
      });
    } else {
      print('No transactions found.');
    }
  } catch (e) {
    print('Error deleting transactions: $e');
  }
}


  Future<void> _removeReport(String key, String providerId, String reportedId, Map<String, dynamic> item) async {
    TextEditingController _reasonController = TextEditingController();
    bool? confirmRemoval = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Rejection'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Are you sure you want to reject this report? This action cannot be undone.'),
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
        await _reportRef.child(key).remove();
        await _sendRejectionMessage(providerId, reportedId, reason, item);
        setState(() {
          _fetchReportData();
        });
      } catch (e) {
        print('Error removing report: $e');
      }
      Navigator.of(context).pop();
    }
  }

  Future<void> _sendRejectionMessage(String providerId, String reportedId, String reason, Map<String, dynamic> item) async {
    try {
      String providerName = await _getName(providerId);
      String reportedUserName = await _getName(reportedId);
      String message = '''
Your submission of the report has been rejected.

Details of the report submission:
- Reported User: $reportedUserName
- Reason: ${item['reason'] ?? 'Unknown Reason'}

Reason for rejection:
$reason
''';
      ChatService chatService = ChatService();
      await chatService.sendMessage(providerId, message);
    } catch (e) {
      print('Error sending rejection message: $e');
    }
  }

  Future<void> _sendApprovalMessage(String providerId, String reportedId, Map<String, dynamic> item) async {
    try {
      String providerName = await _getName(providerId);
      String reportedUserName = await _getName(reportedId);
      String message = '''
Thank you for your prompt action. I have already blocked this user, preventing them from selling any items on eduMart going forward. If you need any further information or assistance regarding this issue, feel free to reach out.

Details of the report submission:
- Reported User: $reportedUserName
- Reason: ${item['reason'] ?? 'Unknown Reason'}
''';
      ChatService chatService = ChatService();
      await chatService.sendMessage(providerId, message);
    } catch (e) {
      print('Error sending approval message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Report', style: GoogleFonts.poppins()),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : surveyData.isEmpty
              ? Center(
                  child: Text(
                    'No report data found.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: surveyData.length,
                  itemBuilder: (context, index) {
                    var item = surveyData[index];
                    return FutureBuilder<List<String>>(
                      future: Future.wait([
                        _getName(item['reporterId']),
                        _getName(item['reportedUserId']),
                      ]),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return CircularProgressIndicator();
                        }
                        if (!snapshot.hasData || snapshot.data == null) {
                          return Text('Error loading names');
                        }

                        String providerName = snapshot.data![0];
                        String reportedUserName = snapshot.data![1];

                        return _buildDataCard(item, providerName, reportedUserName);
                      },
                    );
                  },
                ),
    );
  }

  Widget _buildDataCard(Map<String, dynamic> item, String providerName, String reportedUserName) {
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
            Text(
              'Reported User: $reportedUserName',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF171A1F),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Reason: '+item['reason'] ?? 'Unknown Reason',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 14,
                color: Color(0xFF171A1F),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Reporter: $providerName',
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
                  _removeReport(item['key'], item['reporterId'], item['reportedUserId'], item);
                }),
                _buildActionButton('Approve', Colors.green, () {
                  _approveReport(item['key'], item['reporterId'],  item['reportedUserId'],item);
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Text(label, style: GoogleFonts.poppins(color: Colors.white)),
    );
  }
}
