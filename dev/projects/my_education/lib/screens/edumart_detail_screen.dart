import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_education/screens/chat_person.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

import 'package:fluttertoast/fluttertoast.dart';

class EduMartDetailPage extends StatefulWidget {
  final Map transactionData;

  EduMartDetailPage({required this.transactionData});

  @override
  _EduMartDetailPageState createState() => _EduMartDetailPageState();
}

class _EduMartDetailPageState extends State<EduMartDetailPage> {
  final _descriptionController = TextEditingController();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  late Future<String> _providerNameFuture;
  late Future<String> _providerProfileFuture;
  late String _providerId;
  User? currentUser;
  late String userId;
  int currentPage = 1;

  // Function to fetch the provider's full name from Firestore
  Future<String> fetchProviderName() async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_providerId)
        .get();
    return userDoc.get('fullName') ?? 'Unknown User';
  }

  void _showEditBottomSheet() {
    TextEditingController titleController =
        TextEditingController(text: widget.transactionData['title']);
    TextEditingController descriptionController =
        TextEditingController(text: widget.transactionData['description']);
    TextEditingController priceController =
        TextEditingController(text: widget.transactionData['price'].toString());
    TextEditingController locationController =
        TextEditingController(text: widget.transactionData['location']);

    String? _selectedMethod = widget.transactionData['transactionMethod'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Edit Items',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Colors.orange.shade700, width: 2.0),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Colors.orange.shade700, width: 2.0),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: priceController,
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Price',
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Colors.orange.shade700, width: 2.0),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    // Dropdown for selecting transaction method
                    DropdownButton<String>(
                      value: _selectedMethod,
                      items: <String>['Face to face', 'Online']
                          .map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedMethod = newValue; // Update selected method
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    // 根据选择的交易方式显示位置输入框
                    if (_selectedMethod == 'Face to face') ...[
                      TextField(
                        controller: locationController,
                        decoration: InputDecoration(
                          labelText: 'Location',
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Colors.orange.shade700, width: 2.0),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context); // Close without saving
                          },
                          child: Text('Cancel'),
                        ),
                        SizedBox(width: 8),
                        TextButton(
                          onPressed: () async {
                            String newTitle = titleController.text;
                            String newDescription = descriptionController.text;
                            String newPrice = priceController.text;

                            await updateTransaction(
                                newDescription,
                                newTitle,
                                newPrice,
                                _selectedMethod!,
                                locationController.text);

                            Navigator.pop(context); // Close after saving
                          },
                          child: Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<String> fetchProviderProfile() async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_providerId)
        .get();

    // Check if 'profilePic' field exists in the document
    if (userDoc.data() != null &&
        (userDoc.data() as Map).containsKey('profilePic')) {
      return userDoc.get('profilePic') ?? '';
    } else {
      return ''; // Return an empty string if profilePic doesn't exist
    }
  }

  @override
  void initState() {
    super.initState();

    _providerId = widget.transactionData['provider'];
    currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      userId = currentUser!.uid;
    }
    _providerNameFuture = fetchProviderName();
    _providerProfileFuture = fetchProviderProfile();
    _titleController.text = widget.transactionData['title'] ?? '';
    _descriptionController.text = widget.transactionData['description'] ?? '';
    _priceController.text = widget.transactionData['price'] ?? '';
  }

  @override
  void dispose() {
    // Dispose of controllers properly
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // Function to safely pop context
  void safePop() {
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> deleteTransaction() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Confirm Deletion'),
          content: Text('Are you sure you want to delete this transaction?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog without action
              },
              child: Text('Cancel'),
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () async {
                try {
                  await FirebaseDatabase.instance
                      .ref()
                      .child('transactions')
                      .child(widget.transactionData['id'])
                      .remove(); // Perform deletion

                  // After deletion, we can choose to navigate or refresh the previous page if needed
                  // But we do NOT pop the dialog context here

                  // Optional: Refresh the list or take other actions

                  // Navigator.pop(dialogContext); // Close dialog after deletion
                  safePop(); // You can decide if you want to go back or just refresh
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete transaction')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> updateTransaction(String? newDescription, String? newTitle,
      String? newPrice, String? method, String? location) async {
    // 检查是否有任何必填字段为空
    if (newDescription == null ||
        newDescription.isEmpty ||
        newTitle == null ||
        newTitle.isEmpty ||
        newPrice == null ||
        newPrice.isEmpty || // 也检查 newPrice 是否为空
        method == null ||
        method.isEmpty ||
        (method == 'Face to face' && (location == null || location.isEmpty))) {
      Fluttertoast.showToast(
        msg: 'Please fill in all fields', // 显示提示信息
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM, // Toast 在屏幕底部显示
        timeInSecForIosWeb: 1, // 在 iOS 和 Web 上显示时间
        backgroundColor: Colors.black,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return; // 提前退出，避免继续执行
    }

    try {
      final transactionRef = FirebaseDatabase.instance
          .ref()
          .child('transactions')
          .child(widget.transactionData['id']);

      // 更新数据库中的所有相关字段
      await transactionRef.update({
        'description': newDescription,
        'title': newTitle,
        'price':
            (double.tryParse(newPrice) ?? 0.00).toStringAsFixed(2), // 使用格式化后的价格
        'transactionMethod': method, // 添加交易方式的更新
        'location': method == 'Face to face' ? location : '', // 根据交易方式决定位置
      });

      // 更新本地状态以反映更改
      setState(() {
        widget.transactionData['title'] = newTitle;
        widget.transactionData['description'] = newDescription;
        widget.transactionData['price'] = (double.tryParse(newPrice) ?? 0.00)
            .toStringAsFixed(2); // 更新为格式化后的价格
        widget.transactionData['transactionMethod'] = method; // 更新交易方式
        widget.transactionData['location'] =
            method == 'Face to face' ? location : ''; // 更新位置
      });

      // Navigator.pop(context, true); // 成功后关闭弹出框
    } catch (e) {
      // 处理错误
      Fluttertoast.showToast(
        msg: 'Failed to update transaction', // 错误处理提示
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String dateTimeString = widget.transactionData['dateTime'];

    DateTime dateTime = DateTime.parse(dateTimeString);
    String formattedDate = DateFormat('dd MMM yyyy hh:mm a').format(dateTime);

    return FutureBuilder<String>(
      future: _providerNameFuture,
      builder: (context, nameSnapshot) {
        if (nameSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              actions: [Icon(Icons.more_vert)],
              title: Text('Loading...', style: GoogleFonts.poppins()),
            ),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (nameSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              actions: [Icon(Icons.more_vert)],
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
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  actions: [Icon(Icons.more_vert)],
                  title: Text('Loading...', style: GoogleFonts.poppins()),
                ),
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (profileSnapshot.hasError) {
              return Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  actions: [Icon(Icons.more_vert)],
                  title: Text('Error', style: GoogleFonts.poppins()),
                ),
                body: Center(child: Text('Failed to load user data.')),
              );
            }

            String fullName = nameSnapshot.data ?? 'Unknown User';
            String profilePicUrl = profileSnapshot.data ?? '';
            List<dynamic> imageUrls = widget.transactionData['imageUrls'];

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
                      radius: 24, // Adjust radius as needed
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
                    Text(fullName, style: GoogleFonts.poppins()),
                  ],
                ),
              ),
              body: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Container(
                          height: 400.0,
                          width: double.infinity,
                          child: PageView.builder(
                            itemCount: imageUrls.length,
                            onPageChanged: (index) {
                              setState(() {
                                currentPage = index + 1; // 更新当前页码
                              });
                            },
                            itemBuilder: (context, index) {
                              return Image.network(
                                imageUrls[index],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 450.0,
                              );
                            },
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          left: 10,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 4.0, horizontal: 8.0),
                            color: Colors.black54,
                            child: Text(
                              '$currentPage/${imageUrls.length}',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${widget.transactionData['title']}',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Text('${widget.transactionData['description']}',
                              style: TextStyle(fontSize: 16)),
                          SizedBox(height: 8),
                          Text('RM ${widget.transactionData['price']}',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.orange.shade700)),
                          SizedBox(height: 100),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.payment,
                                      color: Colors.grey,
                                      size: 16), // Icon for Transaction Method
                                  SizedBox(width: 4),
                                  Text(
                                    '${widget.transactionData['transactionMethod']}',
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.grey),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              if (widget.transactionData['location'] != "")
                                Row(
                                  children: [
                                    Icon(Icons.location_on,
                                        color: Colors.grey,
                                        size: 16), // Icon for Location
                                    SizedBox(width: 4),
                                    Text(
                                      '${widget.transactionData['location']}',
                                      style: TextStyle(
                                          fontSize: 14, color: Colors.grey),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          SizedBox(
                            height: 8,
                          ),
                          Text('$formattedDate',
                              style:
                                  TextStyle(fontSize: 14, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              floatingActionButton: userId == _providerId
                  ? FloatingActionButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Edit or Delete'),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showEditBottomSheet();
                                },
                                child: Text('Edit'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await deleteTransaction();
                                  safePop();
                                },
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Icon(Icons.edit, color: Colors.white),
                      backgroundColor: Colors.orange.shade700,
                      shape: CircleBorder(),
                    )
                  : FloatingActionButton(
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ChatPersonPage(
                                      providerId: _providerId,
                                      otherUserID: currentUser!.uid,
                                    )));
                      },
                      child: Icon(Icons.chat, color: Colors.white),
                      backgroundColor: Colors.orange.shade700,
                      shape: CircleBorder(),
                    ),
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
    if (currentUser!.uid == _providerId) {
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
                                'reportedUserId': _providerId, // 被举报用户的 ID
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
}
