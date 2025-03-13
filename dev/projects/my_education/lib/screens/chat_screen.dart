import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_education/screens/chat_person.dart';
import 'package:my_education/screens/robot_chat_page.dart'; // Your detailed chat page

class ChatPage extends StatefulWidget {
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? currentUser;

  @override
  void initState() {
    super.initState();
    currentUser = _auth.currentUser; // Get the current logged-in user
  }

  // Fetch the chat rooms the current user is part of
  Stream<QuerySnapshot> _getUserChats() {
    return _firestore
        .collection('chat_rooms')
        .where('users', arrayContains: currentUser!.uid)
        .snapshots(); // Chat rooms where the current user is a participant
  }

  // Fetch the other user's info from the 'users' collection based on receiverID
  Future<Map<String, dynamic>?> _getOtherUserInfo(String receiverID) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(receiverID).get();
      return userDoc.exists ? userDoc.data() as Map<String, dynamic>? : null;
    } catch (e) {
      print('Error fetching user data: $e');
      return null;
    }
  }

  // Fetch the last message in a chat room
  Future<String?> _getLastMessage(String chatRoomID) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('chat_rooms')
          .doc(chatRoomID)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first['message'] ?? '';
      }
      return '';
    } catch (e) {
      print('Error fetching last message: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Chats', style: GoogleFonts.poppins()),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getUserChats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
                child: Text('No chats yet.',
                    style: TextStyle(color: Colors.grey)));
          }

          var chatRooms = snapshot.data!.docs;

          return ListView.builder(
            itemCount: chatRooms.length,
            itemBuilder: (context, index) {
              var chatRoomData = chatRooms[index];
              var users = chatRoomData['users'] as List<dynamic>;

              // Get the correct receiver ID for the current user
              String otherUserID =
                  users.firstWhere((id) => id != currentUser!.uid);
              String chatRoomID = chatRoomData.id;

              return FutureBuilder<Map<String, dynamic>?>(
                future: _getOtherUserInfo(
                    otherUserID), // Fetch this specific user's info
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return ListTile(title: Text('Loading...'));
                  }
                  if (!userSnapshot.hasData) {
                    return SizedBox.shrink();
                  }

                  var userData = userSnapshot.data!;
                  String fullName = userData['fullName'] ?? 'No Name';
                  String? profilePic = userData['profilePic'];
                  String userType = userData['userType'] ??
                      'user'; // Default to 'user' if no userType

                  return FutureBuilder<String?>(
                    future: _getLastMessage(chatRoomID),
                    builder: (context, messageSnapshot) {
                      String lastMessage =
                          messageSnapshot.data ?? 'No message yet';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              profilePic != null && profilePic.isNotEmpty
                                  ? NetworkImage(profilePic)
                                  : null,
                          backgroundColor: Colors.orange[100],
                          child: profilePic == null || profilePic.isEmpty
                              ? Text(fullName[0].toUpperCase(),
                                  style: TextStyle(
                                      fontSize: 20, color: Colors.orange[800]))
                              : null,
                        ),
                        title: Row(
                          children: [
                            Text(fullName,
                                style: GoogleFonts.poppins(fontSize: 16)),
                            SizedBox(width: 5),
                            // If the user is an admin, show the checkmark icon
                            if (userType == 'admin')
                              Icon(Icons.verified, color: Colors.red, size: 20),
                            if (userType == 'teacher')
                              Icon(Icons.verified,
                                  color: Colors.green, size: 20),
                          ],
                        ),
                        subtitle: Text(lastMessage,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () {
                          // Handle chat room tap, navigate to the detailed chat page
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatPersonPage(
                                  providerId: otherUserID,
                                  otherUserID: currentUser!.uid),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
