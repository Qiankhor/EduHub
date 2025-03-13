import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_education/inchat_online_learning_resources_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  final String tutorId;
  final String tutorName;
  final String studentName;

  const ChatScreen({
    Key? key,
    required this.tutorId,
    required this.tutorName,
    required this.studentName,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _resetUnreadCount();
  }

  Future<void> _resetUnreadCount() async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final chatId = _getChatId(currentUserId, widget.tutorId);

    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
      'unreadCount.$currentUserId': 0,
    });
  }

  Future<String> _getProfileImageUrl(String userId, String role) async {
    try {
      if (role == 'Tutor') {
        final qualificationDoc = await FirebaseFirestore.instance
            .collection('qualifications')
            .doc(userId)
            .get();
        return qualificationDoc.data()?['profileImageUrl'] ??
            'assets/blank_profile.png';
      } else {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        return userDoc.data()?['profileImageUrl'] ?? 'assets/blank_profile.png';
      }
    } catch (e) {
      print('Error fetching profile image URL for $userId: $e');
      return 'assets/blank_profile.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    // Determine if the current user is the tutor
    final isCurrentUserTutor = widget.tutorId == currentUserId;
    final otherParticipantId =
        isCurrentUserTutor ? widget.studentName : widget.tutorId;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(otherParticipantId)
          .get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text("Loading...")),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text("Chat")),
            body: const Center(child: Text("User data not found.")),
          );
        }

        final userData = userSnapshot.data!;
        final otherParticipantName = userData['username'] ?? "Unknown";
        final role = userData['role'];

        return FutureBuilder<String>(
          future: _getProfileImageUrl(otherParticipantId, role),
          builder: (context, profileSnapshot) {
            final profileImageUrl = profileSnapshot.hasData
                ? profileSnapshot.data!
                : 'assets/blank_profile.png';

            return Scaffold(
              appBar: AppBar(
                title: Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: NetworkImage(profileImageUrl),
                    ),
                    const SizedBox(width: 10),
                    Text(otherParticipantName),
                  ],
                ),
                actions: [
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                InchatOnlineLearningResourcesScreen(
                                  chatId:
                                      _getChatId(currentUserId, widget.tutorId),
                                  isCurrentUserTutor: isCurrentUserTutor,
                                )),
                      );
                    },
                    icon: const Icon(Icons.book),
                    tooltip: "Learning Materials",
                  )
                ],
              ),
              body: Column(
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('chats')
                          .doc(_getChatId(currentUserId, widget.tutorId))
                          .collection('messages')
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(child: Text("No messages yet."));
                        }

                        final messages = snapshot.data!.docs;
                        return ListView.builder(
                          reverse: true,
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final isCurrentUser =
                                message['senderId'] == currentUserId;
                            return Align(
                              alignment: isCurrentUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                margin: const EdgeInsets.symmetric(
                                    vertical: 5, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: isCurrentUser
                                      ? Colors.blue[100]
                                      : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(message['message']),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: const InputDecoration(
                              hintText: "Type your message...",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: () => _sendMessage(
                            currentUserId,
                            widget.tutorId,
                            widget.studentName,
                            widget.tutorName,
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
  }

  void _sendMessage(
    String userId,
    String tutorId,
    String studentName,
    String tutorName,
  ) async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    final chatId = _getChatId(userId, tutorId);
    final recipientId = userId == tutorId ? studentName : tutorId;

    // Correctly store the participant names in the correct order based on sender
    final participantNames = userId == tutorId
        ? [
            tutorName,
            studentName
          ] // Store names correctly for tutor as first participant
        : [
            studentName,
            tutorName
          ]; // Store names correctly for student as first participant

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': userId,
      'message': messageText,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'participants': [userId, tutorId],
      'participantNames':
          participantNames, // Store participant names in correct order
      'lastMessage': messageText,
      'timestamp': FieldValue.serverTimestamp(),
      'unreadCount': {
        recipientId: FieldValue.increment(1),
      },
    }, SetOptions(merge: true));

    _messageController.clear();
  }

  String _getChatId(String userId, String tutorId) {
    return userId.hashCode <= tutorId.hashCode
        ? '$userId\_$tutorId'
        : '$tutorId\_$userId';
  }
}
