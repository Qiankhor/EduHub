import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_education/screens/change_password.dart';
import 'package:my_education/screens/points_rewards.dart';
import 'package:my_education/screens/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class SettingsPage extends StatefulWidget {
  
  SettingsPage();

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

  class _SettingsPageState extends State<SettingsPage> {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
   final _storage = FirebaseStorage.instanceFor(
  bucket: "myeducation-865f1.appspot.com", 
);

  final ImagePicker _picker = ImagePicker();
    String _fullName = '';
    String _email = '';
    String? _profilePicUrl;
    bool _loading = true;

      @override
  void initState() {
    super.initState();
    _fetchUserData();
  }
Future<void> _fetchUserData() async {
  try {
    // 获取当前用户
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // 从Firestore中获取用户数据
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        // 确保小部件仍然挂载
        if (mounted) {
          setState(() {
            _fullName = userDoc.data().toString().contains('fullName') 
                ? userDoc['fullName'] 
                : 'No Name'; 
            _email = userDoc.data().toString().contains('email') 
                ? userDoc['email'] 
                : 'No Email'; 
            _profilePicUrl = userDoc.data().toString().contains('profilePic')
                ? userDoc['profilePic']
                : null;
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _fullName = 'User not found';
            _email = 'Email not found';
            _profilePicUrl = null;
            _loading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _fullName = 'No user logged in';
          _email = 'No user logged in';
          _profilePicUrl = null;
          _loading = false;
        });
      }
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _fullName = 'Error fetching user data';
        _email = 'Error fetching user data';
        _profilePicUrl = null;
        _loading = false;
      });
    }
    print('Error fetching user data: $e');
  }
}


 Future<void> _uploadProfilePic() async {
  
  try {
    // 显示加载指示器
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (BuildContext context) {
        return Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    // 从图库中选择图片
    final XFile? pickedImage = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedImage != null) {
      File imageFile = File(pickedImage.path);
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // 上传图片到Firebase Storage
        String filePath = 'profile_pics/${user.uid}.png';
        await _storage.ref(filePath).putFile(imageFile);

        // 获取下载URL
        String downloadURL = await _storage.ref(filePath).getDownloadURL();

        // 将URL保存到Firestore
        await _firestore.collection('users').doc(user.uid).update({
          'profilePic': downloadURL,
        });

        // 更新UI中的头像
        setState(() {
          _profilePicUrl = downloadURL;
        });
      }
    }
  } catch (e) {
    print('Error uploading profile picture: $e');
  } finally {
    // 隐藏加载指示器
    Navigator.of(context).pop();
  }
}

  @override
  Widget build(BuildContext context){
    return Scaffold(
         appBar: AppBar(
          automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text('Settings',style: GoogleFonts.poppins()),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 20,),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              SizedBox(width: 16,),
                 GestureDetector(
  child: Stack(
    children: [
      
 CircleAvatar(
  radius: 40,
  backgroundImage: _profilePicUrl != null && _profilePicUrl!.isNotEmpty
      ? NetworkImage(_profilePicUrl!)
      : null,
  backgroundColor: _profilePicUrl == null || _profilePicUrl!.isEmpty 
      ? Colors.orange[100] // Light blue background for the initial
      : Colors.transparent, // No background if profile picture exists
  child: _profilePicUrl == null || _profilePicUrl!.isEmpty
      ? Text(
          _fullName.isNotEmpty ? _fullName[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.orange[800], // Dark blue text for contrast
          ),
        )
      : null,
  // Optional border for more definition
  // Add this line if you want to visually separate the avatar
  // foregroundColor: Colors.blueAccent,
),
SizedBox(width: 20,),

      Positioned(
        bottom: 0, // Adjust the position of the edit icon
        right: 0,
        child: GestureDetector(
          onTap: _uploadProfilePic, // Change profile picture on tap
          child: CircleAvatar(
            radius: 15,
            backgroundColor: Colors.orange[700], // Set background color for the icon
            child: Icon(
              Icons.edit, // Edit icon
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
      ),
    ],
  ),
),
 SizedBox(width: 10,),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
         
          Text(_fullName,style: TextStyle(fontWeight: FontWeight.bold,fontSize: 18),), 
          Text(_email,style: TextStyle(color: Colors.grey,fontSize: 12),),
        ],
      ),
            ],
            
            ),
            Column(
              children: [
                Container(
                margin: EdgeInsets.all(25),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.orange[50],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children:[ Text("Points to Rewards",style: TextStyle(fontWeight: FontWeight.bold),),
                  GestureDetector(
                    onTap: (){
                      Navigator.push(context, MaterialPageRoute(builder: (context)=>PointsToRewardsPage()));
                    },
                    child: Icon(Icons.arrow_forward_ios_rounded)),
                  ],
                  ),
                  
                          ),
                          Container(
                margin: EdgeInsets.all(25),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.orange[50],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children:[ Text("Change Password",style: TextStyle(fontWeight: FontWeight.bold),),
                  GestureDetector(
                    onTap: (){
                      Navigator.push(context, MaterialPageRoute(builder: (context)=>ChangePasswordPage()));
                    },
                    child: Icon(Icons.arrow_forward_ios_rounded)),
                  ],
                  ),
                  
                          ),
                          
              ],
              
            ),
          Container(
            padding: EdgeInsets.all(25),
                margin: EdgeInsets.fromLTRB(0, 32, 0, 15),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                  ),
                  onPressed: (){
                    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              "Log Out",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text("Are you sure you want to log out?"),
            actions: [
              TextButton(
                child: Text("No"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text("Yes"),
                onPressed: () async {
                  Navigator.of(context).pop(); 
                  await _logout(context); 
                },
              ),
            ],
          );
        },
      );
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 12),
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        'Log Out',
                        style: GoogleFonts.getFont(
                          'Poppins',
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          height: 1.4,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],

        ),
        
      ),
    );
    
  }
     Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
      
    } catch (e) {
      print('Error signing out: $e');
    }
    
  
}
}