import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddClassRoomScreen extends StatefulWidget {
  const AddClassRoomScreen({super.key});

  @override
  State<AddClassRoomScreen> createState() => _AddClassRoomScreenState();
}

class _AddClassRoomScreenState extends State<AddClassRoomScreen> {
  final TextEditingController _classCodeController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isJoining = false;

  Future<void> _joinClassroom() async {
    final code = _classCodeController.text.trim().toUpperCase();
    final user = _auth.currentUser;

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a classroom code.")),
      );
      return;
    }

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please sign in to join a classroom.")),
      );
      return;
    }

    setState(() {
      _isJoining = true;
    });

    try {
      // Check if classroom exists with the given code
      final classroomQuery = await _firestore
          .collection('classrooms')
          .where('classCode', isEqualTo: code)
          .where('isActive', isEqualTo: true)
          .get();

      if (classroomQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Classroom with code '$code' not found.")),
        );
        return;
      }

      final classroomDoc = classroomQuery.docs.first;
      final classroomData = classroomDoc.data();
      final classroomId = classroomDoc.id;

      // Check if user is already in this classroom
      final students = List<String>.from(classroomData['students'] ?? []);
      if (students.contains(user.uid)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("You are already in this classroom.")),
        );
        return;
      }

      // Add user to classroom's students array
      await _firestore.collection('classrooms').doc(classroomId).update({
        'students': FieldValue.arrayUnion([user.uid])
      });

      // Add classroom to user's enrolled classrooms
      await _firestore.collection('users').doc(user.uid).set({
        'enrolledClassrooms': FieldValue.arrayUnion([classroomId]),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Successfully joined ${classroomData['className']}!"),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to home screen
      Navigator.pushNamedAndRemoveUntil(
          context,
          '/home',
              (route) => false
      );

    } catch (e) {
      print('Error joining classroom: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to join classroom: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isJoining = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Join Classroom"),
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // 🖼️ Top image banner
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  'https://images.unsplash.com/photo-1596496059864-3e1f11449b95?auto=format&fit=crop&w=900&q=60',
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 30),

              // 🔤 Text field for class code
              TextField(
                controller: _classCodeController,
                decoration: InputDecoration(
                  hintText: "Enter Classroom Code",
                  labelText: "Classroom Code",
                  prefixIcon: const Icon(Icons.vpn_key_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 18, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                    borderSide: BorderSide(color: Colors.blueAccent, width: 2),
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 30),

              // 🌈 Gradient "Join Classroom" button
              GestureDetector(
                onTap: _isJoining ? null : _joinClassroom,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: _isJoining
                        ? LinearGradient(
                      colors: [Colors.grey.shade400, Colors.grey.shade500],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : const LinearGradient(
                      colors: [Colors.blueAccent, Colors.lightBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: _isJoining
                        ? null
                        : [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isJoining
                        ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          "Joining...",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    )
                        : const Text(
                      "Join Classroom",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 💬 Small note
              Text(
                "Enter the classroom code shared by your teacher or CR to join.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _classCodeController.dispose();
    super.dispose();
  }
}