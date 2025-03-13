import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_education/models/message.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> sendMessage(String receiverID, String message) async {
    String currentUserID = _auth.currentUser!.uid;
    String currentUserEmail = _auth.currentUser!.email!;
    final Timestamp timestamp = Timestamp.now();

    // 创建新消息对象
    Message newMessage = Message(
      senderID: currentUserID,
      senderEmail: currentUserEmail,
      receiverID: receiverID,
      message: message,
      timestamp: timestamp,
    );

    List<String> ids = [currentUserID, receiverID];
    ids.sort();
    String chatRoomID = ids.join('_');

    // 检查聊天房间是否存在，如果不存在则创建它
    DocumentSnapshot chatRoomSnapshot =
        await _firestore.collection('chat_rooms').doc(chatRoomID).get();

    if (!chatRoomSnapshot.exists) {
      await _firestore.collection('chat_rooms').doc(chatRoomID).set({
        'users': ids,
        'lastMessage': message,
        'lastMessageTime': timestamp,
      });
    } else {
      await _firestore.collection('chat_rooms').doc(chatRoomID).update({
        'lastMessage': message,
        'lastMessageTime': timestamp,
      });
    }

    // 将消息添加到消息集合中
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomID)
        .collection('messages')
        .add(newMessage.toMap());

    // 发送通知
    await sendNotification(receiverID, message);
  }

  static Future<String> getAccessToken() async {
final serviceAccountJson = {
    "type": "service_account",
  "project_id": "myeducation-865f1",
  "private_key_id": "66bfa45fd822f49d5c1a954021b6a558f2483854",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC9VloaN+EQzAxC\nd1VOMYFuRqZPCKMyadxM/DMxMxu7yd9MGmVZ2mViM99uG/2G11yh8q1iBPi0yzZN\nBXWOBFHI8On/78pFPRUZ57SCZ/G7oO6tQQ+IhZWWKZjDp2K7BfLHkK5IKH9eV9EG\nE9UJ1f8e/ud+2BwshN5J0BWy3iDqLg+aj1iaeenaEFkiohtWicFzYC3sS9DX13Tk\n/kEVh5ItCvMdDucUoqZOe0QlPuH3Iox8HHcKkYB4ksyRDQMZpCY3N/1Z5rMJvAIV\nT4uJKGaus764XExT7Mc2MEvMJ1vIM2gWnH/OGAYnkT2ZIyOu0EWteFiwg551Joo1\nExkPofJxAgMBAAECggEAAPjjxE3yzS/N2DY6gfwbPilyD4aVTb9XqWEKDPSZjdUU\nHS6aN3qGVsyUCk6UPN6klZo0VZDxOBg+VoNCsEvTIckj6Hbb07YKaOxEykuI/rXH\nBMZ7k0L28Rl6u0MQv/7zmTgwpU/1uUXFHeCY8W1paC7QQHL3Y3g75HmwMAkrA3M4\nEMZbZBYMLac3vMVMqYZ1aMWQu5hMu0edFHoVK2sRlRfMQ8z+GdXaSMZCqxiKc6tE\nGpzFq7k1B2+M33ea36Cha8lT7zJWoaW4YId/dLluMA1SNH5++Tg5hQZn/PtUlcne\ncT/adBLl0IQ/daMrNgjQusMfzrcOmeS0dhLeoHGsyQKBgQD9wEtIjzqQwsNJEBw5\nem9foOhEDWCJXtwu+F9OkPorshj7t7DrRYW5JP7mGbFOgkuw810k/ZsGbqu+5fx6\nEGTEelGzYg5loVodR6lyvwWLUA6OlAgm6HBS0uQ9hNAgbrcGmKnROhFhaBhmnyuv\nQxtuScaRb1bMWxAXHa7THwMUWQKBgQC/A+q+GdynMmxuM2VbCsayNOykWj6TlC5K\ncFRJJMSguSYRyzirUrH0bN7KXceLWOhMa/3Onwl+IghxNrEcST1d9Zyd5P/4rMAg\nv4TAKxSt7iXM/W+wj95nryPNx3NAWxltGRSM+NHqcAs4PsVYAWoNZflFS1uN7CLF\nCWi5Ghjr2QKBgCj34++6GDWJDGh+bmAlUVf6LaXXFw/2vcvjk9emdo2ZeokhdjH2\nDon+3BygZ00KolfWYuJ3A5F9SsNOdH3sqahDK2+v1C06aMcza7s39hgw+7ivU8Wc\nX44vuGPqToP9/BTXjwtVubqlSNNAvZfVWNdsl9+hPz1NMoLY6wHxDtk5AoGAIVlb\nuIjnX0GMcMkEXxrIigB3eFJRLo7mbhSigoqq0azBmsWyRScQ7q27T/WDiy6gkAci\nrtpRW/YxJyL3VQrsbeUdzOtYTWBLwuvtD2f2Gk/DxcBRqa/UkqGfTKQP2SKOk9+X\nGO2wKJAbRVygM7c7fs9Y7+IyP9sETwZPhFGsHDECgYEAosRLS5o6c3VGY0EX4Laq\n/DASoci2R/lzOgOnwPlgwTCnHasRiwne+PyKpXB/BsWQIphlv/D0Dt06bhE3AhuO\nWGS0F75bT6qpPcK5XE+Vpu8oUjShjETDCUrl/zKWCtL68GlxeJmakx2Uxzfi4su9\nffEqSTZwJORxpCKJD3pTvy8=\n-----END PRIVATE KEY-----\n",
  "client_email": "my-education@myeducation-865f1.iam.gserviceaccount.com",
  "client_id": "111566471348347513301",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/my-education%40myeducation-865f1.iam.gserviceaccount.com",
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
static Future<void> sendNotification(String receiverID, String messageContent) async {
  // Fetch the device token from Firestore
  DocumentSnapshot userSnapshot = await FirebaseFirestore.instance.collection('users').doc(receiverID).get();

  if (!userSnapshot.exists) {
    print('Receiver does not exist');
    return; // Optionally handle this case
  }

  // Cast the data to a Map<String, dynamic>
  Map<String, dynamic>? userData = userSnapshot.data() as Map<String, dynamic>?;

  if (userData == null) {
    print('No data found for receiver: $receiverID');
    return; // Optionally handle this case
  }

  String? deviceToken = userData['deviceToken']; // Use the index operator here

  if (deviceToken == null) {
    print('Device token not found for receiver: $receiverID');
    return; // Optionally handle this case
  }

  final String serverAccessTokenKey = await getAccessToken();
  String endpointFirebaseCloudMessaging = 'https://fcm.googleapis.com/v1/projects/myeducation-865f1/messages:send';

  final Map<String, dynamic> fcmMessage = {
    'message': {
      'token': deviceToken,
      'notification': {
        'title': 'New Message',
        'body': messageContent,
      }
    }
  };

  final http.Response response = await http.post(
    Uri.parse(endpointFirebaseCloudMessaging),
    headers: <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $serverAccessTokenKey',
    },
    body: jsonEncode(fcmMessage),
  );

  if (response.statusCode == 200) {
    print('Notification sent successfully: ${response.body}');
  } else {
    print('Failed to send FCM message ${response.statusCode}');
  }
}


  // 获取消息流
  Stream<QuerySnapshot> getMessages(String userID, String otherUserID) {
    List<String> ids = [userID, otherUserID];
    ids.sort();
    String chatRoomID = ids.join('_');
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomID)
        .collection('messages')
        .orderBy("timestamp", descending: false)
        .snapshots();
  }
}
