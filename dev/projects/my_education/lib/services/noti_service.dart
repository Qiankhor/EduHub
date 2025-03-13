import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
    final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
    Future<void> registerUser(String email, String password) async {
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    String? fcmToken = await _firebaseMessaging.getToken();

    // 保存用户信息，包括 fcmToken
    await _firestore.collection('users').doc(userCredential.user!.uid).set({
      'email': email,
      'fcmToken': fcmToken,
      // 其他用户信息
    });
  }

    Future<void> loginUser(String email, String password) async {
    UserCredential userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    String? fcmToken = await _firebaseMessaging.getToken();

    // 更新用户的 fcmToken
    await _firestore.collection('users').doc(userCredential.user!.uid).update({
      'fcmToken': fcmToken,
    });
  }


  void initialize() async {
    // 请求通知权限
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('用户已授权通知');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('用户授予临时通知权限');
    } else {
      print('用户拒绝通知权限');
    }

    // 当应用处于前台时，处理消息
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('收到前台消息: ${message.notification?.body}');
      // 在这里处理通知，比如显示一个Snackbar或对话框
    });
  }
}
