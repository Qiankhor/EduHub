import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_education/admin/settings_admin.dart';
import 'package:my_education/services/chat_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view.dart';

class SurveyPageAdmin extends StatefulWidget {
  @override
  _SurveyPageAdminState createState() => _SurveyPageAdminState();
}

class _SurveyPageAdminState extends State<SurveyPageAdmin>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _surveyRef =
      FirebaseDatabase.instance.ref().child('survey');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> surveyData = [];
  List<Map<String, dynamic>> proofData = [];
  bool isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      DataSnapshot snapshot = await _surveyRef.get();
      if (snapshot.exists) {
        Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;

        List<Map<String, dynamic>> surveys = [];
        List<Map<String, dynamic>> proofs = [];

        data.forEach((surveyId, surveyItem) {
          Map<dynamic, dynamic> surveyMap =
              Map<String, dynamic>.from(surveyItem);

          // 处理 Survey 数据
          if (surveyMap['approve'] == false) {
            surveys.add({'key': surveyId, ...surveyMap});
          }

          // 处理 Proof 数据，并关联 surveyId
          if (surveyMap.containsKey('proof')) {
            Map<dynamic, dynamic> proofItems = surveyMap['proof'];
            proofItems.forEach((proofKey, proofValue) {
              proofs.add({
                'surveyId': surveyId, // 关联 surveyId
                'proofId': proofKey, // proof 的 key
                'imageUrl': proofValue['imageUrl'] ?? '',
                'provider': proofValue['provider'] ?? 'Unknown',
                'surveyTheme': surveyMap['surveyTheme'] ?? 'Unknown Theme',
                'targetAudience':
                    surveyMap['targetAudience'] ?? 'Unknown Audience',
              });
            });
          }
        });

        setState(() {
          surveyData = surveys;
          proofData = proofs;
          isLoading = false;
        });
      } else {
        setState(() {
          surveyData = [];
          proofData = [];
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching data: $e');
      setState(() {
        isLoading = false;
      });
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

  Future<void> _launchURL(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> _approveSurvey(
      String key, String providerId, Map<String, dynamic> item) async {
    // Show confirmation dialog
    bool? confirmApproval = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Approval'),
          content: Text('Are you sure you want to approve this survey?'),
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
        await _surveyRef.child(key).update({'approve': true});
        await _sendApprovalMessage(providerId, item);
        setState(() {
          // Refresh data
          _fetchData();
        });
      } catch (e) {
        print('Error approving survey: $e');
      }
      Navigator.of(context).pop();
    }
  }

  Future<void> _removeSurvey(
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
                  'Are you sure you want to reject this survey? This action cannot be undone.'),
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

        // Remove the survey data from the Realtime Database
        await _surveyRef.child(key).remove();

        // Send detailed rejection message to the provider
        await _sendRejectionMessage(providerId, reason, item);

        setState(() {
          // Refresh data after deletion
          _fetchData();
        });
      } catch (e) {
        print('Error removing survey: $e');
      }
      Navigator.of(context).pop();
    }
  }

  Future<void> _removeProof(BuildContext context, String provider,
      String surveyId, String proofId) async {
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
                  'Are you sure you want to reject this survey? This action cannot be undone.'),
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

        // Remove the survey data from the Realtime Database
        await _surveyRef.child(surveyId).child('proof').child(proofId).remove();

        // Send detailed rejection message to the provider
        await _sendRejectPointMessage(provider, reason);

        setState(() {
          // Refresh data after deletion
          _fetchData();
        });
      } catch (e) {
        print('Error removing survey: $e');
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
          transaction.update(userRef, {'points': currentPoints + 50});
        } else {
          transaction.set(userRef, {'points': 50});
        }

        // Create a document reference for the new transaction record
        DocumentReference newTransactionRef =
            transactionRef.doc(); // Generate a new document ID

        // Add the transaction record as part of the transaction
        transaction.set(newTransactionRef, {
          'points': 50,
          'type': 'addition', // or 'deduction' for deductions
          'reason': 'Reject survey distribution',
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      // Prepare a detailed rejection message
      String message = '''
Your submission of the survey has been rejected.

Details of the survey submission:
- Survey Theme: ${item['surveyTheme'] ?? 'Unknown Survey Theme'}
- Target Group: ${item['targetAudience'] ?? 'Unknown Target Group'}

Reason for rejection:
$reason

As a result of this rejection, we have returned 50 points to your account.
''';

      // Use your ChatService to send the message to the provider
      ChatService chatService = ChatService();
      await chatService.sendMessage(providerId, message);
    } catch (e) {
      print('Error sending rejection message: $e');
    }
  }

  Future<void> _sendApprovalMessage(
      String providerId, Map<String, dynamic> item) async {
    try {
      // Fetch the provider's name
      String providerName = await _getProviderName(providerId);

      // Prepare a detailed approval message
      String message = '''
Congratulations! Your submission of the survey has been approved.

Details of the survey submission:
- Survey Theme: ${item['surveyTheme'] ?? 'Unknown Survey Theme'}
- Target Group: ${item['targetAudience'] ?? 'Unknown Target Group'}
''';

      // Use your ChatService to send the message to the provider
      ChatService chatService = ChatService();
      await chatService.sendMessage(providerId, message);
    } catch (e) {
      print('Error sending approval message: $e');
    }
  }

  Widget _buildSurveyTab() {
    return isLoading
        ? Center(child: CircularProgressIndicator())
        : surveyData.isEmpty
            ? Center(
                child: Text(
                  'No survey data found.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: surveyData.length,
                itemBuilder: (context, index) {
                  var item = surveyData[index];
                  return FutureBuilder<String>(
                    future: _getProviderName(item['provider']),
                    builder: (context, snapshot) {
                      String providerName = snapshot.data ?? 'Loading...';
                      return _buildDataCard(item, providerName);
                    },
                  );
                },
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

  Widget _buildProofTab() {
    return proofData.isEmpty
        ? Center(
            child: Text(
              'No proof submissions available.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          )
        : ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: proofData.length,
            itemBuilder: (context, index) {
              var proofItem = proofData[index];
              String surveyId = proofItem['surveyId'] ?? 'Unknown';
              String proofId = proofItem['proofId'] ?? 'Unknown';

              return Card(
                elevation: 2,
                margin: EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Theme Name: ${proofItem['surveyTheme'] ?? 'Unknown Theme'}',
                        style: TextStyle(fontSize: 14),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Target Group: ${proofItem['targetAudience'] ?? 'Unknown Theme'}',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            onPressed: () {
                              // TODO: Add reject functionality
                              _removeProof(context, proofItem['provider'],
                                  surveyId, proofId);
                            },
                            child: Text('Reject'),
                          ),

                          SizedBox(width: 8), // 控制按钮之间的间距
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            onPressed: () {
                              _showApproveDialog(context, proofItem['provider'],
                                  surveyId, proofId);
                            },
                            child: Text('Approve'),
                          ),

                          SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            onPressed: () {
                              _showImageDialog(
                                  context, proofItem['imageUrl'] ?? '');
                            },
                            child: Text('View'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Survey', style: GoogleFonts.poppins()),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Surveys'),
            Tab(text: 'Proofs'),
          ],
          indicatorColor: Colors.orange[700], // 指示器的颜色
          labelColor: Colors.black, // 选中的标签颜色
          unselectedLabelColor: Colors.grey[400],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSurveyTab(),
          _buildProofTab(),
        ],
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
              item['surveyTheme'] ?? 'Unknown Survey Theme',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF171A1F)),
            ),
            SizedBox(height: 4),
            Text(
              "Target Audience: ${item['targetAudience'] ?? 'Unknown Target Audience'}",
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            SizedBox(height: 4),
            Text('Provider: $providerName',
                style: GoogleFonts.manrope(
                    fontSize: 12, color: Color(0xFF9095A0))),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildActionButton('Reject', Colors.red, () {
                  _removeSurvey(item['key'], item['provider'], item);
                }),
                _buildActionButton('Approve', Colors.green, () {
                  _approveSurvey(item['key'], item['provider'], item);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }

  void _showApproveDialog(
      BuildContext context, String provider, String surveyId, String proofId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Approve Proof'),
          content: Text('Are you sure you want to approve this proof?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 关闭对话框
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _approveProof(provider, surveyId, proofId); // 执行删除操作
                Navigator.of(context).pop(); // 关闭对话框
              },
              child: Text('Approve'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _approveProof(
      String providerId, String surveyId, String proofKey) async {
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
      await _surveyRef.child(surveyId).child('proof').child(proofKey).remove();

      await _sendApprovalPointMessage(providerId);

      DocumentReference userRef =
          FirebaseFirestore.instance.collection('users').doc(providerId);

      // 使用 transaction 以确保操作是原子的
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(userRef);

        if (snapshot.exists) {
          // 获取当前 points 值并更新 +10
          int currentPoints = snapshot['points'] ?? 0;
          transaction.update(userRef, {'points': currentPoints + 10});
        } else {
          // 如果文档不存在，创建新文档并设置 points 为 10
          transaction.set(userRef, {'points': 10});
        }
      });

      // Add 10 points to the user's points in Firestore
      //await _updateUserPoints(providerId);

      print('Proof deleted and points updated.');
      await _fetchData();
    } catch (e) {
      print('Error approving proof: $e');
    }
    Navigator.of(context).pop();
  }

  Future<void> _sendRejectPointMessage(String providerId, String reason) async {
    try {
      // Fetch the provider's name and send the chat message
      String providerName = await _getProviderName(providerId);

      // Prepare a detailed rejection message
      String message = '''
Your submission of the proof has been rejected.

Reason for rejection:
$reason 
''';

      // Use your ChatService to send the message to the provider
      ChatService chatService = ChatService();
      await chatService.sendMessage(providerId, message);
    } catch (e) {
      print('Error sending approval message: $e');
    }
  }

  Future<void> _sendApprovalPointMessage(String providerId) async {
    try {
      // Fetch the provider's name
      String providerName = await _getProviderName(providerId);

      // Prepare a detailed approval message
      String message = '''
Congratulations! Your submission of the proof has been approved.

Additionally, you have earned 10 points for this approval. Keep up the great work!

''';

      // Use your ChatService to send the message to the provider
      ChatService chatService = ChatService();
      await chatService.sendMessage(providerId, message);
    } catch (e) {
      print('Error sending approval message: $e');
    }
  }
}
