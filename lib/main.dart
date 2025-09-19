 import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:trevel_booking_app/Auth/login_page.dart';
import 'package:trevel_booking_app/admin/admin_login.dart';
import 'package:trevel_booking_app/firebase_options.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

 class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home:AdminLoginPage(),
    );
  }
}