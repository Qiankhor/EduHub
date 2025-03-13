import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_education/screens/home_page.dart';
import 'package:my_education/screens/login_page.dart';
import 'package:my_education/models/Teachers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_education/services/noti_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await dotenv.load(fileName: ".env");
  NotificationService().initialize();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduHub',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        appBarTheme: AppBarTheme(
          color: Theme.of(context).scaffoldBackgroundColor,
          titleTextStyle: TextStyle(fontSize: 18, color: Colors.black),
          iconTheme: IconThemeData(color: Colors.black), // 这会影响默认的 leading 图标
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),

      //home: HomePage(Teacher(name: '', university: '', imageAsset: '', rating: 0.0, reviews: 0)),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasData) {
            User? user = snapshot.data;

            if (user != null) {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasData && snapshot.data != null) {
                    var userData = snapshot.data!
                        .data(); // Don't cast it to Map<String, dynamic> yet
                    if (userData != null && userData is Map<String, dynamic>) {
                      // Check if userData is not null and is Map
                      return HomePage(Teacher(
                          name: '',
                          university: '',
                          imageAsset: '',
                          rating: 0.0,
                          reviews: 0));
                    } else {
                      return LoginPage(); // Handle the case when data is null or not a Map
                    }
                  } else {
                    return LoginPage(); // Handle the case when snapshot has no data or is null
                  }
                },
              );
            }
          }

          return LoginPage();
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
