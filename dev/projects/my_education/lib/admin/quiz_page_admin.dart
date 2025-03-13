import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_education/admin/quiz_details_admin.dart';
import 'package:my_education/admin/settings_admin.dart';
import 'package:my_education/models/QuizSet.dart';
import 'package:my_education/services/chat_service.dart';
class QuizPageAdmin extends StatefulWidget {
  QuizPageAdmin();

  @override
  _QuizPageAdminState createState() => _QuizPageAdminState();
}

class _QuizPageAdminState extends State<QuizPageAdmin> {
  final DatabaseReference _quizRef = FirebaseDatabase.instance.ref().child('quiz');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, List<QuizSet>> quizSetsByCategory = {};
  String providerId="";

  @override
  void initState() {
    super.initState();
    _fetchQuizData();
  }
Future<void> _fetchQuizData() async {
  try {
    DataSnapshot categoriesSnapshot = await _quizRef.get();

    if (categoriesSnapshot.exists) {
      Map<dynamic, dynamic> categoriesData = categoriesSnapshot.value as Map<dynamic, dynamic>;
      print('Categories Data: $categoriesData'); // Print all categories data

      Map<String, List<QuizSet>> fetchedQuizSetsByCategory = {};

      for (var categoryEntry in categoriesData.entries) {
        String categoryName = categoryEntry.key; // Category name
        Map<dynamic, dynamic> subjectsData = categoryEntry.value as Map<dynamic, dynamic>; // All subjects under the category

        List<QuizSet> fetchedQuizSets = [];

        for (var subjectEntry in subjectsData.entries) {
          String subjectName = subjectEntry.key; // Subject name
          Map<dynamic, dynamic> setsData = subjectEntry.value as Map<dynamic, dynamic>; // All sets under the subject

          for (var setEntry in setsData.entries) {
            String setName = setEntry.key; // Set name
            Map<dynamic, dynamic> setData = setEntry.value as Map<dynamic, dynamic>; // Set data

            // Check the approval status
            if (setData.containsKey('approve') && setData['approve'] == true) {
              continue; // Skip this set if 'approve' is true
            }

            // Extract providerId and count questions
            
            int questionCount = 0;

            if (setData.containsKey('provider')) {
              providerId = setData['provider'] as String;
            }

            // Count the number of questions in the current set
            setData.forEach((key, value) {
              if (key != 'provider' && key != 'approve' && value is Map) {
                questionCount++;
              }
            });

            if (providerId == null) {
              continue; // Skip the set if provider is not found
            }

            DocumentSnapshot providerSnapshot = await _firestore.collection('users').doc(providerId).get();
            Map<String, dynamic>? providerData = providerSnapshot.data() as Map<String, dynamic>?;

            String providerName = providerSnapshot.exists
                ? (providerData?['fullName'] ?? 'Unknown')
                : 'Unknown';

            // Add the QuizSet object with the new subjectName field
          fetchedQuizSets.add(QuizSet(
  categoryName: categoryName,
  subjectName: subjectName,
  setName: setName,
  questionsCount: questionCount,
  providerName: providerName,
  setData: setData, 
  totalSetCount: 0, 
));

          }
        }

        fetchedQuizSetsByCategory[categoryName] = fetchedQuizSets;
      }

      setState(() {
        quizSetsByCategory = fetchedQuizSetsByCategory;
      });

      print('Fetched quiz sets by category: ${quizSetsByCategory.length}');
    } else {
      print('No categories found.');
    }
  } catch (e) {
    print('Error fetching quiz data: $e');
  }
}
 Future<void> _approveQuiz(String categoryName, String subjectName,String setName,String providerId) async {
    // 显示确认对话框
    bool? confirmApproval = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Approval'),
          content: Text('Are you sure you want to approve this quiz set?'),
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
    // 更新 Realtime Database 中的 'approve' 字段为 true
    await _quizRef.child('$categoryName/$subjectName/$setName').update({'approve': true});
    
    // 发送审批消息
    await _sendApprovalMessage(providerId, categoryName, subjectName);

    // 更新 Firestore 中的用户 points 字段 (+20)
    DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(providerId);
    
    // 使用 transaction 以确保操作是原子的
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userRef);

      if (snapshot.exists) {
        // 获取当前 points 值并更新 +20
        int currentPoints = snapshot['points'] ?? 0;
        transaction.update(userRef, {'points': currentPoints + 20});
      } else {
        // 如果文档不存在，创建新文档并设置 points 为 10
        transaction.set(userRef, {'points': 20});
      }
    });
    Navigator.of(context).pop();

    setState(() {
      // 刷新数据
      _fetchQuizData();
    });
  } catch (e) {
    print('Error approving quiz set: $e');
  }
}

    _fetchQuizData();
  }
Future<void> _sendApprovalMessage(String providerId, String category, String subject) async {
  try {
    // Prepare a detailed approval message
    String message = '''
Congratulations! Your submission of the quiz has been approved.

Details of the quiz submission:
- Category: $category 
- Subject: $subject 

Additionally, you have earned 20 points for this approval. Keep up the great work!
''';

    // Log before sending the message
    print('Sending message to provider $providerId: $message');

    // Use your ChatService to send the message to the provider
    ChatService chatService = ChatService();
    await chatService.sendMessage(providerId, message);
  } catch (e) {
    print('Error sending approval message: $e');
  }
}

   Future<void> _removeQuiz(String categoryName, String subjectName,String setName,String providerId) async {
    TextEditingController _reasonController = TextEditingController();
    // 显示确认对话框
    bool? confirmRemoval = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Rejection'),
          content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to reject this quiz? This action cannot be undone.'),
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
        // 更新 Realtime Database 中的 'approve' 字段为 true
        await _quizRef.child('$categoryName/$subjectName/$setName').remove();
        await _sendRejectionMessage(providerId, reason, categoryName,subjectName);
        setState(() {
          // 刷新数据
          _fetchQuizData();
        });
      } catch (e) {
        print('Error approving quiz set: $e');
      }
      Navigator.of(context).pop();
    }
    _fetchQuizData();
  }
  Future<void> _sendRejectionMessage(String providerId, String reason,String category,String subject) async {
  try {

    // Prepare a detailed rejection message
    String message = '''
Your submission of the quiz has been rejected.

Details of the quiz submission:
- Category: $category
- Subject: $subject

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
  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      centerTitle: true,
      title: Text('Quizzes', style: GoogleFonts.poppins()),
      leading: IconButton(
        onPressed: () {
        Navigator.of(context, rootNavigator: true).pop(context);
        },
        icon: Icon(Icons.arrow_back),
      ),
    ),
    body: quizSetsByCategory.isEmpty
    ? Center(child: CircularProgressIndicator()
      )
    : Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: quizSetsByCategory.length,
              itemBuilder: (context, index) {
                String categoryName = quizSetsByCategory.keys.elementAt(index);
                List<QuizSet> quizSets = quizSetsByCategory[categoryName]!
                    .where((quizSet) => quizSet.setData['approve'] == false)
                    .toList();

                // If there are no quiz sets with approve == false, return a centered message
            if (quizSets.isEmpty && quizSetsByCategory.values.every((sets) => sets.every((quizSet) => quizSet.setData['approve'] == true))) {
                  return Center(
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height, // Set height to full height
                      width: MediaQuery.of(context).size.width, // Set width to full width
                      child: Center(
                        child: Text(
                          'No data available for approval.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),
                    ),
                  );
                }

                return quizSets.isNotEmpty
    ? ExpansionTile(
        title: Text(
          categoryName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            height: 1.6,
            color: Color(0xFF171A1F),
          ),
        ),
        children: quizSets.map((quizSet) {
          return Container(
            margin: EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Color(0xFFFFFFFF),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 5,
                ),
                BoxShadow(
                  color: Color(0x33171A1F),
                  offset: Offset(0, 0),
                  blurRadius: 1,
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 17, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quizSet.subjectName,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      height: 1.6,
                      color: Color(0xFF171A1F),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    quizSet.setName,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      height: 1.7,
                      color: Color(0xFF9095A0),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Total questions: ${quizSet.questionsCount}',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      height: 1.7,
                      color: Color(0xFF9095A0),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Provider: ${quizSet.providerName}',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w400,
                      fontSize: 12,
                      height: 1.7,
                      color: Color(0xFF9095A0),
                    ),
                  ),
                  SizedBox(height: 9),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onPressed: () {
                          _removeQuiz(quizSet.categoryName, quizSet.subjectName, quizSet.setName, providerId);
                        },
                        child: Text('Reject'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onPressed: () {
                          _approveQuiz(quizSet.categoryName, quizSet.subjectName, quizSet.setName, providerId);
                        },
                        child: Text('Approve'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QuizSetDetailPage(
                                categoryName: quizSet.categoryName,
                                subjectName: quizSet.subjectName,
                                setName: quizSet.setName,
                                setData: quizSet.setData,
                              ),
                            ),
                          );
                        },
                        child: Text('View'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      )
    : SizedBox(); // Return an empty widget if there are no quiz sets.

              },
            ),
          ),
        ],
      ),

  );
}
}
