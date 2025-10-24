import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edunotify/app/ui/create_class_room_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/home_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  @override
  _RoleSelectionScreenState createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? selectedRole;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF667eea),
                Color(0xFF764ba2),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: 24),
                    // Header Section
                    _buildHeaderSection(),
                    SizedBox(height: 40),
                    // Study Image
                    _buildStudyImage(),
                    SizedBox(height: 50),
                    // Role Selection Text
                    _buildRoleSelectionText(),
                    SizedBox(height: 30),
                    // Role Cards
                    _buildRoleCards(),
                    // Continue Button
                    _buildContinueButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Edu Notify',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),),
      ],
    );
  }

  Widget _buildStudyImage() {
    return Container(
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background decorative elements
          Positioned(
            right: 0,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Main study icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.school,
              color: Colors.white,
              size: 60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelectionText() {
    return Column(
      children: [
        Text(
          'Choose Your Role',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Select your role to continue with the app',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRoleCards() {
    return Column(
      children: [
        _buildRoleCard(
          role: 'Teacher',
          icon: Icons.school,
          description: 'Educator and course instructor',
          isSelected: selectedRole == 'Teacher',
          onTap: () => _selectRole('Teacher'),
        ),
        SizedBox(height: 16),
        _buildRoleCard(
          role: 'Class Representative',
          icon: Icons.people,
          description: 'Student leader and coordinator',
          isSelected: selectedRole == 'CR',
          onTap: () => _selectRole('CR'),
        ),
        SizedBox(height: 16),
        _buildRoleCard(
          role: 'Student',
          icon: Icons.person,
          description: 'Learner and course participant',
          isSelected: selectedRole == 'Student',
          onTap: () => _selectRole('Student'),
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required String role,
    required IconData icon,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: isSelected
            ? Border.all(color: Colors.white, width: 2)
            : null,
        boxShadow: isSelected
            ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Color(0xFF667eea)
                        : Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role,
                        style: TextStyle(
                          color: isSelected ? Color(0xFF667eea) : Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.black54
                              : Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: Color(0xFF667eea),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return Container(
      width: double.infinity,
      height: 56,
      margin: EdgeInsets.only(top: 20),
      child: ElevatedButton(
        onPressed: selectedRole != null ? () async {
          try {
            // Get the logged-in user
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              // Save role to Firestore
              await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                'email': user.email,
                'role': selectedRole,
                'createdAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

              // Navigate to home
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const CreateClassRoomScreen()),
              );
            } else {
              // If user is not logged in (safety check)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User not logged in')),
              );
            }
          } catch (e) {
            print('Error saving role: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to save role: $e')),
            );
          }
        } : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF667eea),
          elevation: 5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          disabledBackgroundColor: Colors.white.withOpacity(0.5),
        ),
        child: Text(
          'Continue',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _selectRole(String role) {
    setState(() {
      selectedRole = role;
    });
  }

}

