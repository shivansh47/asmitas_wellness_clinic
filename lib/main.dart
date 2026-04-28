import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:diet_cure/core/providers/auth_provider.dart';
import 'package:diet_cure/core/router/auth_wrapper.dart';
import 'package:diet_cure/firebase/firebase_options.dart';
// import 'package:diet_cure/screens/login_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, 
  );

  try{
    await FirebaseFirestore.instance.clearPersistence();
  } catch (e) {
    print('Error clearing Firestore persistence: $e');
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const AuthWrapper(),
    );
  }
}