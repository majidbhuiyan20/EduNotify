import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class AssignmentScreen extends StatefulWidget {
  const AssignmentScreen({super.key});

  @override
  State<AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends State<AssignmentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final List<Assignment> _assignments = [];
  final List<Assignment> _completedAssignments = [];
  String? _userRole;
  String? _selectedClassroomId;
  List<Map<String, dynamic>> _classrooms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      setState(() {
        _userRole = userData?['role'] ?? 'Student';
      });

      await _loadClassrooms();
      await _loadAssignments();
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadClassrooms() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      List<Map<String, dynamic>> classrooms = [];

      if (_userRole == 'Teacher' || _userRole == 'CR') {
        final teacherClassrooms = await _firestore
            .collection('classrooms')
            .where('createdBy', isEqualTo: user.uid)
            .where('isActive', isEqualTo: true)
            .get();

        for (final doc in teacherClassrooms.docs) {
          classrooms.add({
            'id': doc.id,
            ...doc.data(),
          });
        }
      } else if (_userRole == 'Student') {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        final userData = userDoc.data();
        final enrolledClassrooms = List<String>.from(userData?['enrolledClassrooms'] ?? []);

        if (enrolledClassrooms.isNotEmpty) {
          final studentClassrooms = await _firestore
              .collection('classrooms')
              .where(FieldPath.documentId, whereIn: enrolledClassrooms)
              .where('isActive', isEqualTo: true)
              .get();

          for (final doc in studentClassrooms.docs) {
            classrooms.add({
              'id': doc.id,
              ...doc.data(),
            });
          }
        }
      }

      setState(() {
        _classrooms = classrooms;
        if (_selectedClassroomId == null && classrooms.isNotEmpty) {
          _selectedClassroomId = classrooms.first['id'];
        }
      });
    } catch (e) {
      print('Error loading classrooms: $e');
    }
  }

  Future<void> _loadAssignments() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      List<Assignment> allAssignments = [];

      if (_userRole == 'Teacher' || _userRole == 'CR') {
        // Load assignments created by teacher
        Query assignmentsQuery = _firestore
            .collection('assignments')
            .where('teacherUid', isEqualTo: user.uid);

        if (_selectedClassroomId != null && _selectedClassroomId!.isNotEmpty) {
          assignmentsQuery = assignmentsQuery.where('classroomId', isEqualTo: _selectedClassroomId);
        }

        final teacherAssignments = await assignmentsQuery.get();

        for (final doc in teacherAssignments.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>?;
            if (data != null) {
              final assignment = Assignment.fromMap(data);
              allAssignments.add(assignment);
            }
          } catch (e) {
            print('Error processing teacher assignment: $e');
          }
        }
      } else if (_userRole == 'Student') {
        // Load assignments from enrolled classrooms
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        final userData = userDoc.data();
        final enrolledClassrooms = List<String>.from(userData?['enrolledClassrooms'] ?? []);

        final classroomsToLoad = _selectedClassroomId != null && _selectedClassroomId!.isNotEmpty
            ? [_selectedClassroomId!]
            : enrolledClassrooms;

        for (final classroomId in classroomsToLoad) {
          try {
            final classroomAssignments = await _firestore
                .collection('assignments')
                .where('classroomId', isEqualTo: classroomId)
                .get();

            for (final doc in classroomAssignments.docs) {
              try {
                final data = doc.data() as Map<String, dynamic>?;
                if (data != null) {
                  final assignment = Assignment.fromMap(data);
                  allAssignments.add(assignment);
                }
              } catch (e) {
                print('Error processing classroom assignment: $e');
              }
            }
          } catch (e) {
            print('Error loading classroom $classroomId assignments: $e');
          }
        }

        // Load student's submission status
        final studentSubmissions = await _firestore
            .collection('assignment_submissions')
            .where('studentUid', isEqualTo: user.uid)
            .get();

        final submissionMap = <String, bool>{};
        for (final doc in studentSubmissions.docs) {
          final data = doc.data();
          submissionMap[data['assignmentId']] = data['isCompleted'] ?? false;
        }

        // Update assignment status based on submissions
        for (final assignment in allAssignments) {
          if (submissionMap[assignment.id] == true) {
            assignment.status = AssignmentStatus.completed;
          }
        }
      }

      // Separate pending and completed assignments
      final pendingAssignments = allAssignments
          .where((assignment) => assignment.status == AssignmentStatus.pending)
          .toList();

      final completedAssignments = allAssignments
          .where((assignment) => assignment.status == AssignmentStatus.completed)
          .toList();

      setState(() {
        _assignments.clear();
        _completedAssignments.clear();
        _assignments.addAll(pendingAssignments);
        _completedAssignments.addAll(completedAssignments);
        _isLoading = false;
      });

    } catch (e) {
      print('Error loading assignments: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsCompleted(Assignment assignment) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      if (_userRole == 'Student') {
        // For students, create/update submission record
        await _firestore
            .collection('assignment_submissions')
            .doc('${assignment.id}_${user.uid}')
            .set({
          'assignmentId': assignment.id,
          'studentUid': user.uid,
          'studentName': user.displayName ?? 'Student',
          'isCompleted': true,
          'completedAt': FieldValue.serverTimestamp(),
          'classroomId': assignment.classroomId,
          'classroomName': assignment.classroomName,
        }, SetOptions(merge: true));
      }

      setState(() {
        _assignments.remove(assignment);
        assignment.status = AssignmentStatus.completed;
        _completedAssignments.add(assignment);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${assignment.title} marked as completed!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error marking assignment as completed: $e');
      _showErrorSnackBar('Failed to mark assignment as completed');
    }
  }

  Future<void> _markAsPending(Assignment assignment) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      if (_userRole == 'Student') {
        // For students, update submission record
        await _firestore
            .collection('assignment_submissions')
            .doc('${assignment.id}_${user.uid}')
            .update({
          'isCompleted': false,
        });
      }

      setState(() {
        _completedAssignments.remove(assignment);
        assignment.status = AssignmentStatus.pending;
        _assignments.add(assignment);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${assignment.title} moved to pending.'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      print('Error marking assignment as pending: $e');
      _showErrorSnackBar('Failed to mark assignment as pending');
    }
  }

  Future<void> _deleteAssignment(Assignment assignment) async {
    try {
      await _firestore.collection('assignments').doc(assignment.id).delete();

      // Also delete related submissions
      final submissions = await _firestore
          .collection('assignment_submissions')
          .where('assignmentId', isEqualTo: assignment.id)
          .get();

      final batch = _firestore.batch();
      for (final doc in submissions.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      setState(() {
        _assignments.remove(assignment);
        _completedAssignments.remove(assignment);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${assignment.title} deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error deleting assignment: $e');
      _showErrorSnackBar('Failed to delete assignment');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showAssignmentDetails(Assignment assignment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AssignmentDetailsBottomSheet(
        assignment: assignment,
        userRole: _userRole,
        onStatusChanged: () {
          if (assignment.status == AssignmentStatus.pending) {
            _markAsCompleted(assignment);
          } else {
            _markAsPending(assignment);
          }
        },
        onDelete: () {
          _deleteAssignment(assignment);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showAddAssignmentDialog() {
    if (_classrooms.isEmpty) {
      _showErrorSnackBar('Please create a classroom first');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AddAssignmentDialog(
        classrooms: _classrooms,
        selectedClassroomId: _selectedClassroomId,
        onAssignmentAdded: (newAssignment) {
          setState(() {
            _assignments.add(newAssignment);
          });
        },
      ),
    );
  }

  void _onClassroomSelected(String? classroomId) {
    setState(() {
      _selectedClassroomId = classroomId;
    });
    _loadAssignments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Assignments',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Text(
                'Pending (${_assignments.length})',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ),
            Tab(
              child: Text(
                'Completed (${_completedAssignments.length})',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading assignments...', style: GoogleFonts.poppins()),
          ],
        ),
      )
          : Column(
        children: [
          // Classroom Selector
          if (_classrooms.isNotEmpty) ...[
            Card(
              margin: EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.school, size: 20, color: Colors.blue),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Classroom Filter',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedClassroomId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Select a classroom',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('All Classrooms', style: GoogleFonts.poppins()),
                        ),
                        ..._classrooms.map<DropdownMenuItem<String>>((classroom) {
                          return DropdownMenuItem<String>(
                            value: classroom['id'] as String?,
                            child: Text(
                              classroom['className'],
                              style: GoogleFonts.poppins(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                      ],
                      onChanged: _onClassroomSelected,
                    ),
                  ],
                ),
              ),
            ),
          ],
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Pending Assignments Tab
                _assignments.isEmpty
                    ? _buildEmptyState(
                  'No pending assignments',
                  Icons.assignment_turned_in,
                  _userRole == 'Student'
                      ? 'No assignments from your classrooms'
                      : 'Create assignments for your students',
                )
                    : RefreshIndicator(
                  onRefresh: _loadAssignments,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _assignments.length,
                    itemBuilder: (context, index) {
                      return AssignmentCard(
                        assignment: _assignments[index],
                        userRole: _userRole,
                        onTap: () => _showAssignmentDetails(_assignments[index]),
                        onComplete: () => _markAsCompleted(_assignments[index]),
                      );
                    },
                  ),
                ),

                // Completed Assignments Tab
                _completedAssignments.isEmpty
                    ? _buildEmptyState(
                  'No completed assignments',
                  Icons.assignment_turned_in,
                  'Completed assignments will appear here',
                )
                    : RefreshIndicator(
                  onRefresh: _loadAssignments,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _completedAssignments.length,
                    itemBuilder: (context, index) {
                      return CompletedAssignmentCard(
                        assignment: _completedAssignments[index],
                        userRole: _userRole,
                        onTap: () => _showAssignmentDetails(_completedAssignments[index]),
                        onReopen: () => _markAsPending(_completedAssignments[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: (_userRole == 'Teacher' || _userRole == 'CR')
          ? FloatingActionButton.extended(
        onPressed: _showAddAssignmentDialog,
        icon: const Icon(Icons.add),
        label: Text('Add Assignment', style: GoogleFonts.poppins()),
        backgroundColor: Colors.blue,
      )
          : null,
    );
  }

  Widget _buildEmptyState(String message, IconData icon, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.poppins(
              color: Colors.grey,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              color: Colors.grey,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class AssignmentCard extends StatelessWidget {
  final Assignment assignment;
  final String? userRole;
  final VoidCallback onTap;
  final VoidCallback onComplete;

  const AssignmentCard({
    super.key,
    required this.assignment,
    required this.userRole,
    required this.onTap,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final daysRemaining = assignment.dueDate.difference(DateTime.now()).inDays;
    final hoursRemaining = assignment.dueDate.difference(DateTime.now()).inHours;
    final isDueSoon = daysRemaining <= 1;
    final isOverdue = assignment.dueDate.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      color: isOverdue ? Colors.red[50] : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Priority Indicator
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getPriorityColor(assignment.priority),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Subject Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getSubjectColor(assignment.subject).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      assignment.subject,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _getSubjectColor(assignment.subject),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Due Date
                  Text(
                    DateFormat('MMM d').format(assignment.dueDate),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isOverdue ? Colors.red : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Classroom Info (for students)
              if (userRole == 'Student') ...[
                Row(
                  children: [
                    Icon(Icons.school, size: 14, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(
                      assignment.classroomName,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
              ],
              // Title
              Text(
                assignment.title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Description
              Text(
                assignment.description,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              // Progress and Action Row
              Row(
                children: [
                  // Time Remaining
                  Icon(
                      Icons.access_time,
                      size: 16,
                      color: isOverdue ? Colors.red : (isDueSoon ? Colors.orange : Colors.grey)
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isOverdue
                        ? 'Overdue by ${-daysRemaining} days'
                        : isDueSoon
                        ? 'Due in $hoursRemaining hours'
                        : 'Due in $daysRemaining days',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isOverdue ? Colors.red : (isDueSoon ? Colors.orange : Colors.grey[600]),
                    ),
                  ),
                  const Spacer(),
                  // Complete Button (only for students)
                  if (userRole == 'Student')
                    ElevatedButton(
                      onPressed: onComplete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'Complete',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(Priority priority) {
    switch (priority) {
      case Priority.high:
        return Colors.red;
      case Priority.medium:
        return Colors.orange;
      case Priority.low:
        return Colors.green;
    }
  }

  Color _getSubjectColor(String subject) {
    final subjectColors = {
      'Mathematics': Colors.blue,
      'Literature': Colors.purple,
      'Computer Science': Colors.teal,
      'History': Colors.orange,
      'Physics': Colors.red,
      'Biology': Colors.green,
      'Chemistry': Colors.deepPurple,
      'Geography': Colors.brown,
    };
    return subjectColors[subject] ?? Colors.grey;
  }
}

class CompletedAssignmentCard extends StatelessWidget {
  final Assignment assignment;
  final String? userRole;
  final VoidCallback onTap;
  final VoidCallback onReopen;

  const CompletedAssignmentCard({
    super.key,
    required this.assignment,
    required this.userRole,
    required this.onTap,
    required this.onReopen,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      color: Colors.grey[50],
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Completed Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'Completed',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Completion Date
                  Text(
                    assignment.completedDate != null
                        ? DateFormat('MMM d').format(assignment.completedDate!)
                        : 'Completed',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Classroom Info (for students)
              if (userRole == 'Student') ...[
                Row(
                  children: [
                    Icon(Icons.school, size: 14, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(
                      assignment.classroomName,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
              ],
              // Title
              Text(
                assignment.title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Description
              Text(
                assignment.description,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              // Action Row
              Row(
                children: [
                  // Subject
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getSubjectColor(assignment.subject).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      assignment.subject,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _getSubjectColor(assignment.subject),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Reopen Button (only for students)
                  if (userRole == 'Student')
                    OutlinedButton(
                      onPressed: onReopen,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'Reopen',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getSubjectColor(String subject) {
    final subjectColors = {
      'Mathematics': Colors.blue,
      'Literature': Colors.purple,
      'Computer Science': Colors.teal,
      'History': Colors.orange,
      'Physics': Colors.red,
      'Biology': Colors.green,
      'Chemistry': Colors.deepPurple,
      'Geography': Colors.brown,
    };
    return subjectColors[subject] ?? Colors.grey;
  }
}

class AssignmentDetailsBottomSheet extends StatelessWidget {
  final Assignment assignment;
  final String? userRole;
  final VoidCallback onStatusChanged;
  final VoidCallback onDelete;

  const AssignmentDetailsBottomSheet({
    super.key,
    required this.assignment,
    required this.userRole,
    required this.onStatusChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = assignment.dueDate.isBefore(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Title
          Text(
            assignment.title,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Subject and Due Date
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getSubjectColor(assignment.subject).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  assignment.subject,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _getSubjectColor(assignment.subject),
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: isOverdue ? Colors.red : Colors.grey
              ),
              const SizedBox(width: 4),
              Text(
                DateFormat('MMM d, yyyy').format(assignment.dueDate),
                style: GoogleFonts.poppins(
                  color: isOverdue ? Colors.red : Colors.grey[600],
                ),
              ),
            ],
          ),
          // Classroom Info
          if (userRole == 'Student') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.school, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  assignment.classroomName,
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          // Description
          Text(
            'Description',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            assignment.description,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          // Priority
          Text(
            'Priority',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getPriorityColor(assignment.priority),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _getPriorityText(assignment.priority),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Action Buttons
          Row(
            children: [
              // Delete Button (only for teachers)
              if ((userRole == 'Teacher' || userRole == 'CR') && assignment.status == AssignmentStatus.pending)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Delete Assignment'),
                          content: Text('Are you sure you want to delete "${assignment.title}"?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                onDelete();
                              },
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Delete',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
              if ((userRole == 'Teacher' || userRole == 'CR') && assignment.status == AssignmentStatus.pending)
                const SizedBox(width: 12),
              // Status Change Button (for students)
              if (userRole == 'Student')
                Expanded(
                  child: ElevatedButton(
                    onPressed: onStatusChanged,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: assignment.status == AssignmentStatus.pending
                          ? Colors.blue
                          : Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      assignment.status == AssignmentStatus.pending
                          ? 'Mark as Completed'
                          : 'Mark as Pending',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getSubjectColor(String subject) {
    final subjectColors = {
      'Mathematics': Colors.blue,
      'Literature': Colors.purple,
      'Computer Science': Colors.teal,
      'History': Colors.orange,
      'Physics': Colors.red,
      'Biology': Colors.green,
      'Chemistry': Colors.deepPurple,
      'Geography': Colors.brown,
    };
    return subjectColors[subject] ?? Colors.grey;
  }

  Color _getPriorityColor(Priority priority) {
    switch (priority) {
      case Priority.high:
        return Colors.red;
      case Priority.medium:
        return Colors.orange;
      case Priority.low:
        return Colors.green;
    }
  }

  String _getPriorityText(Priority priority) {
    switch (priority) {
      case Priority.high:
        return 'High Priority';
      case Priority.medium:
        return 'Medium Priority';
      case Priority.low:
        return 'Low Priority';
    }
  }
}

class AddAssignmentDialog extends StatefulWidget {
  final List<Map<String, dynamic>> classrooms;
  final String? selectedClassroomId;
  final Function(Assignment) onAssignmentAdded;

  const AddAssignmentDialog({
    super.key,
    required this.classrooms,
    required this.selectedClassroomId,
    required this.onAssignmentAdded,
  });

  @override
  State<AddAssignmentDialog> createState() => _AddAssignmentDialogState();
}

class _AddAssignmentDialogState extends State<AddAssignmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subjectController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  Priority _priority = Priority.medium;
  String? _selectedClassroomId;

  final List<String> _subjects = [
    'Mathematics',
    'Literature',
    'Computer Science',
    'History',
    'Physics',
    'Biology',
    'Chemistry',
    'Geography',
  ];

  @override
  void initState() {
    super.initState();
    _selectedClassroomId = widget.selectedClassroomId ??
        (widget.classrooms.isNotEmpty ? widget.classrooms.first['id'] : null);
  }

  Future<void> _selectDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final user = _auth.currentUser;
      if (user == null || _selectedClassroomId == null) return;

      try {
        // Get classroom data
        final classroomDoc = await _firestore
            .collection('classrooms')
            .doc(_selectedClassroomId!)
            .get();

        final classroomData = classroomDoc.data();
        if (classroomData == null) {
          throw Exception('Classroom not found');
        }

        final assignmentId = DateTime.now().millisecondsSinceEpoch.toString();

        // Create assignment in Firestore
        await _firestore.collection('assignments').doc(assignmentId).set({
          'id': assignmentId,
          'title': _titleController.text,
          'subject': _subjectController.text,
          'dueDate': Timestamp.fromDate(_dueDate),
          'description': _descriptionController.text,
          'priority': _priority.index,
          'status': AssignmentStatus.pending.index,
          'teacherUid': user.uid,
          'teacherName': user.displayName ?? 'Teacher',
          'classroomId': _selectedClassroomId,
          'classroomName': classroomData['className'],
          'createdAt': FieldValue.serverTimestamp(),
        });

        final newAssignment = Assignment(
          id: assignmentId,
          title: _titleController.text,
          subject: _subjectController.text,
          dueDate: _dueDate,
          description: _descriptionController.text,
          status: AssignmentStatus.pending,
          priority: _priority,
          teacherUid: user.uid,
          teacherName: user.displayName ?? 'Teacher',
          classroomId: _selectedClassroomId!,
          classroomName: classroomData['className'],
          createdAt: DateTime.now(),
        );

        widget.onAssignmentAdded(newAssignment);
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Assignment created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        print('Error creating assignment: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create assignment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create New Assignment',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Classroom Selector
              DropdownButtonFormField<String>(
                value: _selectedClassroomId,
                items: widget.classrooms.map((classroom) {
                  return DropdownMenuItem<String>(
                    value: classroom['id'] as String,
                    child: Text(classroom['className']),
                  );
                }).toList(),
                onChanged: (String? value) {
                  setState(() {
                    _selectedClassroomId = value;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Classroom',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a classroom';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Assignment Title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Subject Dropdown
              DropdownButtonFormField<String>(
                value: _subjectController.text.isEmpty ? null : _subjectController.text,
                items: _subjects.map((String subject) {
                  return DropdownMenuItem<String>(
                    value: subject,
                    child: Text(subject),
                  );
                }).toList(),
                onChanged: (String? value) {
                  setState(() {
                    _subjectController.text = value!;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a subject';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Due Date Picker
              InkWell(
                onTap: _selectDueDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Due Date',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('MMM d, yyyy').format(_dueDate)),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Priority Selector
              Text(
                'Priority',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildPriorityChip(Priority.low, 'Low'),
                  const SizedBox(width: 8),
                  _buildPriorityChip(Priority.medium, 'Medium'),
                  const SizedBox(width: 8),
                  _buildPriorityChip(Priority.high, 'High'),
                ],
              ),
              const SizedBox(height: 16),

              // Description Field
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Create Assignment',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityChip(Priority priority, String label) {
    final isSelected = _priority == priority;
    return Expanded(
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _priority = priority;
          });
        },
        backgroundColor: Colors.grey[200],
        selectedColor: _getPriorityColor(priority),
        labelStyle: GoogleFonts.poppins(
          color: isSelected ? Colors.white : Colors.grey[700],
        ),
      ),
    );
  }

  Color _getPriorityColor(Priority priority) {
    switch (priority) {
      case Priority.high:
        return Colors.red;
      case Priority.medium:
        return Colors.orange;
      case Priority.low:
        return Colors.green;
    }
  }
}

// Data Models
enum AssignmentStatus { pending, completed }
enum Priority { low, medium, high }

class Assignment {
  String id;
  String title;
  String subject;
  DateTime dueDate;
  String description;
  AssignmentStatus status;
  Priority priority;
  DateTime? completedDate;
  String teacherUid;
  String teacherName;
  String classroomId;
  String classroomName;
  DateTime createdAt;

  Assignment({
    required this.id,
    required this.title,
    required this.subject,
    required this.dueDate,
    required this.description,
    required this.status,
    required this.priority,
    this.completedDate,
    required this.teacherUid,
    required this.teacherName,
    required this.classroomId,
    required this.classroomName,
    required this.createdAt,
  });

  factory Assignment.fromMap(Map<String, dynamic> map) {
    return Assignment(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      subject: map['subject']?.toString() ?? '',
      dueDate: (map['dueDate'] as Timestamp).toDate(),
      description: map['description']?.toString() ?? '',
      status: AssignmentStatus.values[map['status'] is int ? map['status'] : 0],
      priority: Priority.values[map['priority'] is int ? map['priority'] : 1],
      completedDate: map['completedDate'] != null ? (map['completedDate'] as Timestamp).toDate() : null,
      teacherUid: map['teacherUid']?.toString() ?? '',
      teacherName: map['teacherName']?.toString() ?? '',
      classroomId: map['classroomId']?.toString() ?? '',
      classroomName: map['classroomName']?.toString() ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Assignment copyWith({
    String? id,
    String? title,
    String? subject,
    DateTime? dueDate,
    String? description,
    AssignmentStatus? status,
    Priority? priority,
    DateTime? completedDate,
    String? teacherUid,
    String? teacherName,
    String? classroomId,
    String? classroomName,
    DateTime? createdAt,
  }) {
    return Assignment(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      dueDate: dueDate ?? this.dueDate,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      completedDate: completedDate ?? this.completedDate,
      teacherUid: teacherUid ?? this.teacherUid,
      teacherName: teacherName ?? this.teacherName,
      classroomId: classroomId ?? this.classroomId,
      classroomName: classroomName ?? this.classroomName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}