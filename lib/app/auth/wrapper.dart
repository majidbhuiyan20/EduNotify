import 'package:edunotify/app/auth/login_screen.dart';
import 'package:edunotify/app/ui/role_selection_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../features/home_screen.dart';


class WrapperScreen extends StatefulWidget {
  const WrapperScreen({super.key});

  @override
  State<WrapperScreen> createState() => _WrapperScreenState();
}

class _WrapperScreenState extends State<WrapperScreen> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            // Print user data from Firestore
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .get(),
              builder: (BuildContext context,
                  AsyncSnapshot<DocumentSnapshot> documentSnapshot) {
                if (documentSnapshot.connectionState == ConnectionState.done) {
                  if (documentSnapshot.data != null && documentSnapshot.data!.exists) {
                    return HomeScreen();
                  }
                  return RoleSelectionScreen();
                }
                return Scaffold(body: Center(child: CircularProgressIndicator()));
              }
            );
          } else {
            return LoginScreen();
          }
        });
  }
}