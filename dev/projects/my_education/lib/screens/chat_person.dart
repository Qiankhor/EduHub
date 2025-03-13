import 'dart:ui' if (dart.library.html) 'dart:ui_web';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_education/components/chat_bubble.dart';
import 'package:my_education/services/chat_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';

class ChatPersonPage extends StatefulWidget {
  final String providerId;

  ChatPersonPage({required this.providerId, required String otherUserID});

  @override
  _ChatPersonPageState createState() => _ChatPersonPageState();
}

class _ChatPersonPageState extends State<ChatPersonPage> {
  User? currentUser = FirebaseAuth.instance.currentUser;
  late Future<String> _providerNameFuture;
  late Future<String> _providerProfileFuture;
  late Future<String> _providerUserTypeFuture;
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();

  // 定义 ScrollController
  final ScrollController _scrollController = ScrollController();

  void sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      await _chatService.sendMessage(
          widget.providerId, _messageController.text.trim());
      _messageController.clear();
      _scrollToBottom();
    }
  }

  // 滚动到底部函数
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  Future<String> fetchProviderName() async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.providerId)
        .get();
    return userDoc.get('fullName') ?? 'Unknown User';
  }

  Future<String> fetchProviderProfile() async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.providerId)
        .get();

    if (userDoc.data() != null &&
        (userDoc.data() as Map<String, dynamic>).containsKey('profilePic')) {
      return userDoc.get('profilePic');
    } else {
      return '';
    }
  }

  Future<String> fetchUserType() async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.providerId)
        .get();
    return userDoc.get('userType') ?? 'Unknown User';
  }

  @override
  void initState() {
    super.initState();
    _providerNameFuture = fetchProviderName();
    _providerProfileFuture = fetchProviderProfile();
    _providerUserTypeFuture = fetchUserType();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _providerNameFuture,
      builder: (context, nameSnapshot) {
        if (nameSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Loading...', style: GoogleFonts.poppins()),
            ),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (nameSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Error', style: GoogleFonts.poppins()),
            ),
            body: Center(child: Text('Failed to load user data.')),
          );
        }

        return FutureBuilder<String>(
          future: _providerProfileFuture,
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                appBar: AppBar(
                  title: Text('Loading...', style: GoogleFonts.poppins()),
                ),
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (profileSnapshot.hasError) {
              return Scaffold(
                appBar: AppBar(
                  title: Text('Error', style: GoogleFonts.poppins()),
                ),
                body: Center(child: Text('Failed to load user data.')),
              );
            }

            return FutureBuilder<String>(
              future: _providerUserTypeFuture,
              builder: (context, userTypeSnapshot) {
                if (userTypeSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return Scaffold(
                    appBar: AppBar(
                      title: Text('Loading...', style: GoogleFonts.poppins()),
                    ),
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (userTypeSnapshot.hasError) {
                  return Scaffold(
                    appBar: AppBar(
                      title: Text('Error', style: GoogleFonts.poppins()),
                    ),
                    body: Center(child: Text('Failed to load user data.')),
                  );
                }

                String fullName = nameSnapshot.data ?? 'Unknown User';
                String profilePicUrl = profileSnapshot.data ?? '';
                String userType = userTypeSnapshot.data ?? 'user';

                return Scaffold(
                  appBar: AppBar(
                    leading: IconButton(
                      icon: Icon(Icons.arrow_back),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    actions: [
                      PopupMenuButton<int>(
                        icon: Icon(Icons.more_vert),
                        onSelected: (value) {
                          if (value == 1) {
                            _showReportBottomSheet(context);
                          }
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<int>>[
                          PopupMenuItem<int>(
                            value: 1,
                            child: Row(
                              children: [
                                Icon(Icons.report, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Report'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    title: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: profilePicUrl.isNotEmpty
                              ? NetworkImage(profilePicUrl)
                              : null,
                          child: profilePicUrl.isEmpty
                              ? Text(
                                  fullName.isNotEmpty ? fullName[0] : '?',
                                  style: TextStyle(fontSize: 24),
                                )
                              : null,
                        ),
                        SizedBox(width: 8),
                        Text(fullName,
                            style: GoogleFonts.poppins(fontSize: 16)),
                        if (userType == 'admin')
                          IconButton(
                            icon: Icon(Icons.verified, color: Colors.red),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Text("Admin User"),
                                    content: Text("$fullName is an Admin."),
                                    actions: <Widget>[
                                      TextButton(
                                        child: Text("OK"),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        if (userType == 'teacher')
                          IconButton(
                            icon: Icon(Icons.verified, color: Colors.green),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Text("Tutor"),
                                    content: Text("$fullName is a tutor."),
                                    actions: <Widget>[
                                      TextButton(
                                        child: Text("OK"),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  body: Column(
                    children: [
                      Expanded(child: _buildMessageList()),
                      Container(
                        padding:
                            EdgeInsets.only(bottom: 16, left: 16, right: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                cursorColor: Colors.black,
                                decoration: InputDecoration(
                                  hintText: 'Enter your message',
                                  filled: true,
                                  fillColor: Colors.grey[200],
                                  contentPadding: EdgeInsets.symmetric(
                                      vertical: 15.0, horizontal: 15.0),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                    borderSide: BorderSide(
                                        color: Colors.grey[300]!, width: 1.0),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                    borderSide: BorderSide(
                                        color: Colors.orange.shade700,
                                        width: 2.0),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade700,
                                      borderRadius: BorderRadius.circular(50),
                                    ),
                                    child: IconButton(
                                      onPressed: () {
                                        sendMessage();
                                        _messageController.clear();
                                      },
                                      icon: Icon(
                                        Icons.arrow_upward,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showReportBottomSheet(BuildContext context) {
    TextEditingController reportController = TextEditingController();
    File? evidenceImage; // 变量存储上传的图片
    bool _isUploading = false; // 上传状态指示器
    double _uploadProgress = 0.0; // 上传进度

    // Check if the current user is different from the provider
    if (currentUser!.uid == widget.providerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You cannot report yourself.')),
      );
      return; // Exit the function since user cannot report themselves
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16.0,
            right: 16.0,
            top: 16.0,
          ),
          child: Wrap(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Report User',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  Text('Are you sure you want to report this user?'),
                  SizedBox(height: 8),
                  TextField(
                    controller: reportController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: Colors.orange.shade700, width: 2.0),
                      ),
                      labelText: 'Reason for reporting',
                    ),
                    maxLines: 1,
                  ),
                  SizedBox(height: 16),
                  // Image upload button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    onPressed: () async {
                      // 选择图片
                      final pickedFile = await ImagePicker()
                          .pickImage(source: ImageSource.gallery);
                      if (pickedFile != null) {
                        setState(() {
                          evidenceImage =
                              File(pickedFile.path); // 使用 setState 更新图片
                        });
                      }
                    },
                    child: Text('Upload Evidence Image'),
                  ),
                  SizedBox(height: 8),
                  // 如果选中了图片，则显示
                  if (evidenceImage != null) ...[
                    Image.file(evidenceImage!, height: 100),
                    SizedBox(height: 8),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context); // Close the bottom sheet
                        },
                        child: Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          String reason = reportController.text;

                          if (reason.isNotEmpty && evidenceImage != null) {
                            setState(() {
                              _isUploading = true; // 开始上传
                              _uploadProgress = 0.0; // Reset progress
                            });

                            try {
                              // 上传图片到 Firebase Storage
                              final storageRef = FirebaseStorage.instanceFor(
                                      bucket: "myeducation-865f1.appspot.com")
                                  .ref()
                                  .child(
                                      'report_images/${DateTime.now().toIso8601String()}');

                              // 上传文件
                              final uploadTask =
                                  storageRef.putFile(evidenceImage!);

                              // Listen for upload progress
                              uploadTask.snapshotEvents
                                  .listen((TaskSnapshot snapshot) {
                                setState(() {
                                  _uploadProgress = snapshot.bytesTransferred /
                                      snapshot.totalBytes;
                                });
                              });

                              final snapshot =
                                  await uploadTask.whenComplete(() {});

                              // 获取下载 URL
                              String imagePath =
                                  await snapshot.ref.getDownloadURL();
                              print('Image uploaded successfully: $imagePath');

                              // 生成唯一的报告键
                              String key =
                                  FirebaseDatabase.instance.ref().push().key!;

                              // 保存报告数据
                              await FirebaseDatabase.instance
                                  .ref()
                                  .child('reports')
                                  .child(key)
                                  .set({
                                'id': key,
                                'reason': reason,
                                'reporterId': currentUser!.uid, // 当前用户的 ID
                                'reportedUserId':
                                    widget.providerId, // 被举报用户的 ID
                                'timestamp':
                                    DateTime.now().toIso8601String(), // 时间戳
                                'imagePath': imagePath, // 存储上传的图片 URL
                              });

                              // 显示成功消息
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('Report submitted successfully')),
                              );
                            } catch (e) {
                              // 处理错误
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Failed to submit report')),
                              );
                            } finally {
                              setState(() {
                                _isUploading = false; // 隐藏进度指示器
                              });
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Reason cannot be empty and image must be uploaded')),
                            );
                          }

                          Navigator.pop(context); // Close the bottom sheet
                        },
                        child: Text('Submit'),
                      ),
                    ],
                  ),
                  if (_isUploading)
                    Column(
                      children: [
                        SizedBox(height: 16),
                        LinearProgressIndicator(
                            value: _uploadProgress), // 线性进度条显示上传进度
                        SizedBox(height: 16),
                      ],
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageList() {
    String senderID = currentUser!.uid;
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getMessages(widget.providerId, senderID),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading messages.'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No messages yet.'));
        }

        // 自动滚动到底部
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        return ListView(
          controller: _scrollController, // 使用 ScrollController
          children:
              snapshot.data!.docs.map((doc) => _buildMessageItem(doc)).toList(),
        );
      },
    );
  }

  Widget _buildMessageItem(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    bool isCurrentUser = data['senderID'] == currentUser!.uid;
    var alignment =
        isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;
    return Container(
      alignment: alignment,
      child: Column(
        crossAxisAlignment:
            isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ChatBubble(message: data["message"], isCurrentUser: isCurrentUser),
        ],
      ),
    );
  }
}
