import 'dart:math';

import 'package:edunotify/app/features/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateClassRoomScreen extends StatefulWidget {
  const CreateClassRoomScreen({super.key});

  @override
  State<CreateClassRoomScreen> createState() => _CreateClassRoomScreenState();
}

class _CreateClassRoomScreenState extends State<CreateClassRoomScreen> {
  final TextEditingController _classNameController = TextEditingController();
  final TextEditingController _classCodeController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _teacherEmailController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isCreating = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _additionalTeachers = [];

  @override
  void dispose() {
    _classCodeController.dispose();
    _classNameController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    _teacherEmailController.dispose();
    super.dispose();
  }

  Future<void> _addTeacherByEmail() async {
    final email = _teacherEmailController.text.trim();
    if (email.isEmpty) {
      _showErrorDialog('Please enter a teacher email');
      return;
    }

    if (email == _auth.currentUser?.email) {
      _showErrorDialog('You cannot add yourself as a co-teacher');
      return;
    }

    try {
      // Check if teacher exists and has teacher/CR role
      final users = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .where('role', whereIn: ['Teacher', 'CR'])
          .get();

      if (users.docs.isEmpty) {
        _showErrorDialog('No teacher or CR found with email: $email');
        return;
      }

      final teacherDoc = users.docs.first;
      final teacherData = teacherDoc.data();
      final teacherId = teacherDoc.id;

      // Check if teacher is already added
      if (_additionalTeachers.any((teacher) => teacher['id'] == teacherId)) {
        _showErrorDialog('Teacher already added to this classroom');
        return;
      }

      setState(() {
        _additionalTeachers.add({
          'id': teacherId,
          'name': teacherData['displayName'] ?? 'Teacher',
          'email': email,
          'role': teacherData['role'] ?? 'Teacher',
        });
        _teacherEmailController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Teacher ${teacherData['displayName'] ?? email} added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showErrorDialog('Error adding teacher: $e');
    }
  }

  void _removeTeacher(String teacherId) {
    setState(() {
      _additionalTeachers.removeWhere((teacher) => teacher['id'] == teacherId);
    });
  }

  Future<void> _createClassroom() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isCreating = true;
      });

      try {
        User? user = _auth.currentUser;

        if (user == null) {
          _showErrorDialog('Please sign in to create a classroom');
          return;
        }

        // Check if class code already exists
        final classCodeExists = await _firestore
            .collection('classrooms')
            .where('classCode', isEqualTo: _classCodeController.text.trim())
            .get()
            .then((snapshot) => snapshot.docs.isNotEmpty);

        if (classCodeExists) {
          _showErrorDialog('Class code already exists. Please choose a different code.');
          return;
        }

        // Extract teacher IDs for the teachers array
        final teacherIds = _additionalTeachers.map((teacher) => teacher['id'] as String).toList();

        // Create classroom document
        await _firestore.collection('classrooms').add({
          'className': _classNameController.text.trim(),
          'classCode': _classCodeController.text.trim().toUpperCase(),
          'subject': _subjectController.text.trim(),
          'description': _descriptionController.text.trim(),
          'createdBy': user.uid,
          'createdByEmail': user.email,
          'createdAt': FieldValue.serverTimestamp(),
          'teacherName': user.displayName ?? 'Unknown Teacher',
          'teachers': teacherIds, // Array of teacher IDs
          'students': [], // Empty list for students to join
          'isActive': true,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // Show success dialog
        _showSuccessDialog();

      } catch (e) {
        _showErrorDialog('Failed to create classroom: $e');
      } finally {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.green,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              // Success Text
              const Text(
                'Classroom Created!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Classroom "${_classNameController.text}" with code "${_classCodeController.text.toUpperCase()}" has been created successfully.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),

              // Show co-teachers if any
              if (_additionalTeachers.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Co-Teachers Added:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ..._additionalTeachers.map((teacher) => ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    child: Text(teacher['name'].toString().substring(0, 1)),
                  ),
                  title: Text(teacher['name']),
                  subtitle: Text(teacher['email']),
                )).toList(),
              ],

              const SizedBox(height: 20),
              // Action Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> HomeScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Error', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Generate a random class code if needed
  void _generateClassCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final code = String.fromCharCodes(
      Iterable.generate(
        6,
            (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
    _classCodeController.text = code;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Create Classroom'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Header Image
              _buildHeaderImage(),
              const SizedBox(height: 32),

              // Title
              _buildTitleSection(),
              const SizedBox(height: 32),

              // Class Name Field
              _buildClassNameField(),
              const SizedBox(height: 20),

              // Subject Field
              _buildSubjectField(),
              const SizedBox(height: 20),

              // Class Code Field
              _buildClassCodeField(),
              const SizedBox(height: 20),

              // Description Field
              _buildDescriptionField(),
              const SizedBox(height: 20),

              // Add Co-Teachers Section
              _buildCoTeachersSection(),
              const SizedBox(height: 32),

              // Create Classroom Button
              _buildCreateButton(),
              const SizedBox(height: 20),

              // Tips Section
              _buildTipsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderImage() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade400, Colors.purple.shade400],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade200.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Pattern
          Positioned(
            right: -50,
            top: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Main Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Classroom Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                  child: const Icon(
                    Icons.school,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Create Your Classroom',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      children: [
        Text(
          'Create New Classroom',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Set up your virtual classroom and start teaching',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildClassNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Class Name',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: _classNameController,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a class name';
              }
              if (value.length < 3) {
                return 'Class name must be at least 3 characters';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: 'CSE 1st Semester',
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.class_, color: Colors.blue.shade700, size: 20),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Subject',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: _subjectController,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a subject';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: 'Computer Science, Mathematics, etc.',
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.subject, color: Colors.green.shade700, size: 20),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.green.shade400, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildClassCodeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Class Code',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _generateClassCode,
              child: Text(
                'Generate Code',
                style: TextStyle(
                  color: Colors.blue.shade600,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: _classCodeController,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a class code';
              }
              if (value.length < 4) {
                return 'Class code must be at least 4 characters';
              }
              return null;
            },
            inputFormatters: [
              UpperCaseTextFormatter(),
            ],
            decoration: InputDecoration(
              hintText: 'e.g., CSE31',
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.qr_code, color: Colors.purple.shade700, size: 20),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.purple.shade400, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            style: const TextStyle(fontSize: 16, letterSpacing: 1.2),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description (Optional)',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Describe your classroom, course objectives, etc.',
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.description, color: Colors.orange.shade700, size: 20),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.orange.shade400, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildCoTeachersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add Co-Teachers (Optional)',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Add other teachers who should have full access to this classroom',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),

        // Add Teacher Input
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: _teacherEmailController,
                  decoration: InputDecoration(
                    hintText: 'Enter teacher email',
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person_add, color: Colors.teal.shade700, size: 20),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.teal.shade500,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.shade300.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: _addTeacherByEmail,
                icon: const Icon(Icons.add, color: Colors.white),
                tooltip: 'Add Teacher',
              ),
            ),
          ],
        ),

        // Added Teachers List
        if (_additionalTeachers.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Co-Teachers:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ..._additionalTeachers.map((teacher) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.teal.shade100,
                child: Text(
                  teacher['name'].toString().substring(0, 1),
                  style: TextStyle(
                    color: Colors.teal.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(teacher['name']),
              subtitle: Text('${teacher['email']} • ${teacher['role']}'),
              trailing: IconButton(
                icon: Icon(Icons.remove_circle, color: Colors.red.shade400),
                onPressed: () => _removeTeacher(teacher['id']),
                tooltip: 'Remove Teacher',
              ),
            ),
          )).toList(),
        ],
      ],
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: _isCreating
              ? null
              : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade600, Colors.purple.shade600],
          ),
          boxShadow: _isCreating
              ? null
              : [
            BoxShadow(
              color: Colors.blue.shade300.withOpacity(0.5),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isCreating ? null : _createClassroom,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isCreating ? Colors.grey.shade400 : Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
            shadowColor: Colors.transparent,
          ),
          child: _isCreating
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
                'Creating Classroom...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          )
              : const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 20),
              SizedBox(width: 8),
              Text(
                'Create Classroom',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lightbulb, color: Colors.blue.shade700, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                'Pro Tips',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTipItem('Use a clear and descriptive class name'),
          _buildTipItem('Class codes must be unique and at least 4 characters'),
          _buildTipItem('Share the class code with students to join'),
          _buildTipItem('Co-teachers will have full editing permissions'),
          _buildTipItem('Only Teachers and CRs can be added as co-teachers'),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 6, color: Colors.blue.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Text formatter to convert text to uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}