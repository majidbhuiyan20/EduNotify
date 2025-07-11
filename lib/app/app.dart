import 'package:edunotify/app/auth/wrapper.dart';
import 'package:edunotify/app/home/home_screen.dart';
import 'package:flutter/material.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auth UI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: false),
      home: WrapperScreen(),
      // initialRoute: '/',
      // routes: {
      //   // '/': (_) => const WrapperScreen(),
      //   // '/home': (_) => const HomeScreen(),
      //   // '/login': (_) => const LoginScreen(),
      //   // '/signup': (_) => const SignUpScreen(),
      // },
    );
  }
}





// lib/
// ├── main.dart
// ├── routes/
// │   └── app_route.dart      
// ├── views/
// │   ├── login/
// │   │   ├── login_screen.dart
// │   │   └── login_view_model.dart
// │   └── home/
// │       ├── home_screen.dart
// │       └── home_view_model.dart
// ├── models/
// ├── view_models/
// │   └── global_view_model.dart
// └── services/