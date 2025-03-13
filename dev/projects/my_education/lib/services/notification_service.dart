import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:googleapis/servicecontrol/v1.dart' as servicecontrol;

class NotificationService {
  static Future<String> getAccessToken() async {
    final serviceAccountJson = {
      "type": "service_account",
      "project_id": "educonnect-410d6",
      "private_key_id": "a8b94724a0ddc280c4c84b0f8f0c9df10be8427e",
      "private_key":
          "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCsnv+3VSVMux3/\nCUU/WpC/8W9em/3yihOFM1zY+lxRcWsT0Y4GZJMyGSwomBo7hlo5PkH15Wy9qioi\nNrwdp7Ju9tGfivlrVKIYaej8WowfEqlYGz7mYKZ2cg/jgsszLP5323ecyjcHXcui\nEo4ffFx6IH8F2nfjmZmZ+nTgNVN8/IWtaVbLZp9lNxuqErJC7Wv74VUWVmGnZSqb\nkCEtF2vSzZU1Q73MCQXe3ZSmzYLFMLOyhERLqPthUNrGAemiBk3KOnl6pwaOvNzI\nGncwr6mk8sGfOwY/buHsHl74fqZYQOB3uL+l5nn0SDGFBdj83toy4mDn3s35mNo9\noL3qvEcrAgMBAAECggEABYYQFLkVcZSt631LyU0ymJHFczeTFrjdtbU575afxS/X\nsfw1/MphxTMSV8eH/1yCV+vqv/oJbzIL4HBlt7qLku5Qv1QzywAb205b2Ry5+HV2\nacceTbQGCkdbp7BM3St4hmzh3BM0cAbLqgA645MJnhNFdisnthFrFmqALEK6WzGu\ngqDWLVWTCC748/K1x1umIMSbrhpAFh5G/XTt52Wop+TZFkyu/uhDqg4ORa3rgfqc\nQK1kcn+3WDmLNWWfqAKVD6PZJIMxR/sLTvvE4eg8JhkIrj8XPG4ZLez7HuCm1WOQ\nDGxOK2FgPCZbCr28MS3N1QV6sPmtrAp6fe7vrZpqsQKBgQDxjUm/mdZ3wLRO2pk9\nQPTwE7hACMpQuEhh0R760/yXjalLjxBTcLTZ7+8URb9s+4sh2qNXnT5Rfo6Vswnj\nox05E/DVEs7g3D7WAY2IQOZZOMN7gaSiEuYfHGmygtYoRHwNRYCGlfH9cCZw8FjV\n0A9qf9GNnKkt8nXeb0blhML+pQKBgQC28jjwCqpzYma4YTdTttf+eUhp7cMxXEFa\nK8/EMFvYxgeaWS/5lZtrX0XPtFbiqkXx6BAK/ukRksmp0YSFyGH3Afhhw6ETtEwX\nLyhHynVgJJZKIwpzXpV6ImyhriNHVFZucn7DSXdQW0mXpcClqg6upHlT2UHHzbeM\ngcJVLBKVjwKBgQCKOO1gpKljMXR8Qv65XHhNARvIGL+c3TceMkpmAfRizP95a05O\nUQpMQ84tbZQSywZcwv4BXsuQWrlA1IjuKCLKzKxdYTvc1Gtojs7sjybBG4hRHmiV\nDfd9Cgc5zUC7HiVWetUHLrqg6hI1QnOzNjH8IVRKksEEt9/W/xo0sHncuQKBgGH4\nZTVnANC5qXij1xUlnZXRLU5M3XLZjMXVIHZXz1fO9NNbX62wyII/iwsn8D+CH+Lj\n+3Nn/zhB+2zNnsJmBNBaZcE1GlWLABSKVG/do+3QqgsZqMcPp8y4EqSitJHGQGL1\nPZ0nApYtzMNBKGGPKD2uJqsYdXmiWOENvBwQdgNRAoGAS5NCJSYkNQZrZxBJNMU9\nrZZFGA0RM2otF0lc0PmmqIy5oKiz3p31/XihpqtlpcKtdGWbOCEnwb5Ba1nuD/E8\nrJq9xrZLWhvgFZTxGyS0pTfH33NwHU/hF7BmcxWffvlFBMOrwPb911aYulDUgec2\ngomjflzvY2slUDY3f5Rl07k=\n-----END PRIVATE KEY-----\n",
      "client_email": "educonnect@educonnect-410d6.iam.gserviceaccount.com",
      "client_id": "100182362273880615544",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url":
          "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url":
          "https://www.googleapis.com/robot/v1/metadata/x509/educonnect%40educonnect-410d6.iam.gserviceaccount.com",
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
            client);

    client.close();

    return credentials.accessToken.data;
  }

  static sendNotificationToTutor(
      String deviceToken,
      BuildContext context,
      String bookingId,
      String date,
      String timeSlot,
      String currentUserName,
      bool isBooking,
      bool isRescheduling,
      bool isCancelling) async {
    final String serverAccessTokenKey = await getAccessToken();
    String endPointFirebaseCloudMessaging =
        'https://fcm.googleapis.com/v1/projects/educonnect-410d6/messages:send';

    String title;
    if (isBooking) {
      title = "Booking Request from $currentUserName";
    } else if (isRescheduling) {
      title = "Rescheduling from $currentUserName";
    } else if (isCancelling) {
      title = "Booking Cancellation from $currentUserName";
    } else {
      title =
          "Notification from $currentUserName"; // Default title if none match
    }

    final Map<String, dynamic> message = {
      'message': {
        'token': deviceToken,
        'notification': {
          'title': title,
          'body': "Booking date: $date \nBooking time: $timeSlot"
        },
        'data': {
          'bookingId': bookingId,
        }
      }
    };

    final http.Response response = await http.post(
      Uri.parse(endPointFirebaseCloudMessaging),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $serverAccessTokenKey'
      },
      body: jsonEncode(message),
    );
    if (response.statusCode == 200) {
      print('Notification sent successfully');
    } else {
      print('Failed to send FCM message: ${response.body}');
    }
  }

  static sendNotificationToStudent(
      String deviceToken,
      BuildContext context,
      String bookingId,
      String date,
      String timeSlot,
      String tutorName,
      bool isAccepted,
      bool isCanceled) async {
    final String serverAccessTokenKey = await getAccessToken();
    String endPointFirebaseCloudMessaging =
        'https://fcm.googleapis.com/v1/projects/educonnect-410d6/messages:send';

    String title;
    if (isAccepted) {
      title = "Booking Accepted by $tutorName";
    } else if (isCanceled) {
      title = "Booking Canceled by $tutorName";
    } else {
      title = "Notification from $tutorName"; // Default title if none match
    }

    final Map<String, dynamic> message = {
      'message': {
        'token': deviceToken,
        'notification': {
          'title': title,
          'body': "Booking date: $date \nBooking time: $timeSlot"
        },
        'data': {
          'bookingId': bookingId,
        }
      }
    };

    final http.Response response = await http.post(
      Uri.parse(endPointFirebaseCloudMessaging),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $serverAccessTokenKey'
      },
      body: jsonEncode(message),
    );

    if (response.statusCode == 200) {
      print('Notification sent successfully');
    } else {
      print('Failed to send FCM message: ${response.body}');
    }
  }

  static sendSessionNotification(
      String studentDeviceToken,
      String tutorDeviceToken,
      String bookingId,
      String date,
      String timeSlot) async {
    final String serverAccessTokenKey = await getAccessToken();
    String endPointFirebaseCloudMessaging =
        'https://fcm.googleapis.com/v1/projects/educonnect-410d6/messages:send';

    // Common notification details
    final List<Map<String, dynamic>> message = [
      {
        'token': studentDeviceToken,
        'notification': {
          'title': 'Upcoming Session Reminder',
          'body': 'Your session is starting soon! Date: $date, Time: $timeSlot',
        },
        'data': {
          'bookingId': bookingId,
        }
      },
      {
        'token': tutorDeviceToken,
        'notification': {
          'title': 'Upcoming Session Reminder',
          'body':
              'You have a session starting soon! Date: $date, Time: $timeSlot',
        },
        'data': {
          'bookingId': bookingId,
        }
      }
    ];

    final http.Response response = await http.post(
      Uri.parse(endPointFirebaseCloudMessaging),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $serverAccessTokenKey'
      },
      body: jsonEncode(message),
    );

    if (response.statusCode == 200) {
      print('Notification sent successfully');
    } else {
      print('Failed to send FCM message: ${response.body}');
    }
  }
}
