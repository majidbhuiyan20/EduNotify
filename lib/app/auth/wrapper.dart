import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edunotify/app/auth/login_screen.dart';
import 'package:edunotify/app/ui/role_selection_ui.dart';
import 'package:edunotify/app/features/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WrapperScreen extends StatefulWidget {
  const WrapperScreen({super.key});

  @override
  State<WrapperScreen> createState() => _WrapperScreenState();
}

class _WrapperScreenState extends State<WrapperScreen> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 🔹 Case 1: No authenticated user
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        final user = snapshot.data!;

        // 🔹 Case 2: Authenticated user — check Firestore for user document
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, AsyncSnapshot<DocumentSnapshot> documentSnapshot) {
            if (documentSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // 🔹 Case 3: Firestore data exists
            if (documentSnapshot.hasData && documentSnapshot.data!.exists) {
              return const HomeScreen();
            }

            // 🔹 Case 4: No Firestore data found → RoleSelectionScreen
            debugPrint("No Firestore user data found for ${user.email}");
            return  RoleSelectionScreen();
          },
        );
      },
    );
  }
}
