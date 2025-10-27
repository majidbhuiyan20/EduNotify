import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edunotify/app/features/assignment_screen.dart';
import 'package:edunotify/app/features/notification_screen.dart';
import 'package:edunotify/app/features/settings_screen.dart';
import 'package:edunotify/app/ui/add_class_room_screen.dart';
import 'package:edunotify/app/ui/create_class_room_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../auth/login_screen.dart';
import '../ui/role_selection_ui.dart';
import 'schedule_screen.dart';

// A function type for handling navigation from child widgets
typedef void GoToPageCallback(int pageIndex);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  int _currentIndex = 0;
  late final List<Widget> _screens;
  String? _userRole;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _screens = [
      DashboardScreen(onNavigate: _navigateToPage, userRole: _userRole),
      const ScheduleScreen(),
      const AssignmentScreen(),
      const NotificationScreen(),
      SettingsScreen(),
    ];
  }

  Future<void> _checkUserRole() async {
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _userRole = userData?['role'];
          _isLoading = false;
        });

        // If no role is selected, navigate to role selection
        if (_userRole == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
            );
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        // If user document doesn't exist, navigate to role selection
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
          );
        });
      }
    } catch (e) {
      print('Error checking user role: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToPage(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _showJoinClassDialog() {
    TextEditingController classCodeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Join Class', style: GoogleFonts.poppins()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the class code provided by your teacher',
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: classCodeController,
              decoration: InputDecoration(
                labelText: 'Class Code',
                border: OutlineInputBorder(),
                hintText: 'e.g., MATH1012024',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final classCode = classCodeController.text.trim();
              if (classCode.isNotEmpty) {
                Navigator.pop(context);
                await _joinClass(classCode);
              }
            },
            child: const Text('Join Class'),
          ),
        ],
      ),
    );
  }

  Future<void> _joinClass(String classCode) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Find classroom by class code
      final classroomQuery = await FirebaseFirestore.instance
          .collection('classrooms')
          .where('classCode', isEqualTo: classCode)
          .where('isActive', isEqualTo: true)
          .get();

      if (classroomQuery.docs.isEmpty) {
        _showSnackBar('Classroom not found. Please check the class code.', Colors.red);
        return;
      }

      final classroomDoc = classroomQuery.docs.first;
      final classroomData = classroomDoc.data();
      final students = List<String>.from(classroomData['students'] ?? []);

      // Check if already enrolled
      if (students.contains(user.uid)) {
        _showSnackBar('You are already enrolled in this classroom.', Colors.orange);
        return;
      }

      // Add student to enrolled list
      await classroomDoc.reference.update({
        'students': FieldValue.arrayUnion([user.uid])
      });

      // Add classroom to user's enrolled classrooms
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'enrolledClassrooms': FieldValue.arrayUnion([classroomDoc.id]),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _showSnackBar('Successfully joined classroom!', Colors.green);

      // Refresh the dashboard
      setState(() {});

    } catch (e) {
      _showSnackBar('Error joining classroom: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  void _navigateToCreateClassroom() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateClassRoomScreen()),
    ).then((_) {
      // Refresh when returning from create classroom
      setState(() {});
    });
  }

  void _navigateToAddClassroom() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddClassRoomScreen()),
    ).then((_) {
      // Refresh when returning from add classroom
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading...', style: GoogleFonts.poppins()),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: _currentIndex == 0
          ? AppBar(
        title: Text(
          'Edu Notify',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
            },
          ),
          // Show join class button for all roles
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: _showJoinClassDialog,
            tooltip: 'Join Class',
          ),
        ],
      )
          : null,

      ///Drawer Start here
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.blue,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(
                      user?.displayName?.substring(0, 1) ?? 'U',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.displayName ?? 'User Name',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    user?.email ?? 'user@email.com',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                    ),
                  ),
                  if (_userRole != null) ...[
                    const SizedBox(height: 8),
                    Chip(
                      label: Text(
                        _userRole!,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: Colors.white.withOpacity(0.3),
                    ),
                  ],
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: Text('Dashboard', style: GoogleFonts.poppins()),
              onTap: () {
                setState(() {
                  _currentIndex = 0;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text('Schedule', style: GoogleFonts.poppins()),
              onTap: () {
                setState(() {
                  _currentIndex = 1;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment),
              title: Text('Assignments', style: GoogleFonts.poppins()),
              onTap: () {
                setState(() {
                  _currentIndex = 2;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: Text('Notifications', style: GoogleFonts.poppins()),
              onTap: () {
                setState(() {
                  _currentIndex = 3;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text('Settings', style: GoogleFonts.poppins()),
              onTap: () {
                setState(() {
                  _currentIndex = 4;
                });
                Navigator.pop(context);
              },
            ),

            // Classroom Management Section based on role
            if (_userRole == 'Teacher' || _userRole == 'CR') ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add_circle),
                title: Text('Create Classroom', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToCreateClassroom();
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_add),
                title: Text('Add Classroom', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToAddClassroom();
                },
              ),
            ],

            const Divider(),
            ListTile(
              leading: const Icon(Icons.group_add),
              title: Text('Join Class', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                _showJoinClassDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: Text('Logout', style: GoogleFonts.poppins()),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                      (route) => false,
                );
              },
            ),
          ],
        ),
      ),
      ///Drawer Ends Here

      body: _screens[_currentIndex],

      /// Bottom Navigation Start Here
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Assignments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      /// Bottom Navigation End Here

      // Floating Action Button based on role
      floatingActionButton: _currentIndex == 0
          ? (_userRole == 'Teacher' || _userRole == 'CR')
          ? FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Classroom Management'),
              content: Text('Choose an option'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToCreateClassroom();
                  },
                  child: Text('Create Classroom'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToAddClassroom();
                  },
                  child: Text('Add Classroom'),
                ),
              ],
            ),
          );
        },
        icon: Icon(Icons.add),
        label: Text('Classroom'),
      )
          : (_userRole == 'Student')
              ? FloatingActionButton.extended(
                  onPressed: _showJoinClassDialog,
                  icon: const Icon(Icons.group_add),
                  label: const Text('Join Classroom'),
                )
              : null // No FAB for other roles or if role is null
          : null,
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final GoToPageCallback onNavigate;
  final String? userRole;
  const DashboardScreen({super.key, required this.onNavigate, required this.userRole});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<ClassEvent> _todayClasses = [];
  List<ClassEvent> _tomorrowClasses = [];
  List<ClassEvent> _rescheduledClasses = [];
  bool _isLoading = true;
  String _displayTitle = "Today's Classes";

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      print('Loading classes for user: ${user.uid}');

      // Get user's role and enrolled classrooms
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      final userRole = userData?['role'] ?? 'Student';
      final enrolledClassrooms = List<String>.from(userData?['enrolledClassrooms'] ?? []);

      List<ClassEvent> allClasses = [];

      if (userRole == 'Teacher' || userRole == 'CR') {
        // Load classes created by this teacher
        final teacherClasses = await _firestore
            .collection('classes')
            .where('teacherUid', isEqualTo: user.uid)
            .get();

        for (final doc in teacherClasses.docs) {
          try {
            final classEvent = ClassEvent.fromMap(doc.data());
            allClasses.add(classEvent);
          } catch (e) {
            print('Error processing teacher class: $e');
          }
        }
      }

      // Load classes from enrolled classrooms
      for (final classroomId in enrolledClassrooms) {
        try {
          final classroomClasses = await _firestore
              .collection('classes')
              .where('classroomId', isEqualTo: classroomId)
              .get();

          for (final doc in classroomClasses.docs) {
            try {
              final classEvent = ClassEvent.fromMap(doc.data());
              allClasses.add(classEvent);
            } catch (e) {
              print('Error processing enrolled class: $e');
            }
          }
        } catch (e) {
          print('Error loading classroom $classroomId: $e');
        }
      }

      // Load rescheduled classes
      final rescheduledClasses = await _firestore
          .collection('rescheduled_classes')
          .where('classroomId', whereIn: enrolledClassrooms)
          .where('newDate', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .get();

      List<ClassEvent> todayClasses = [];
      List<ClassEvent> tomorrowClasses = [];
      List<ClassEvent> rescheduledClassList = [];

      // Filter classes by date
      for (final classEvent in allClasses) {
        try {
          final classDate = classEvent.date;
          final classDateOnly = DateTime(classDate.year, classDate.month, classDate.day);

          if (classDateOnly.isAtSameMomentAs(today)) {
            todayClasses.add(classEvent);
          } else if (classDateOnly.isAtSameMomentAs(tomorrow)) {
            tomorrowClasses.add(classEvent);
          }
        } catch (e) {
          print('Error processing class date: $e');
        }
      }

      // Process rescheduled classes
      for (final doc in rescheduledClasses.docs) {
        try {
          final data = doc.data();
          final originalClass = ClassEvent(
            id: data['originalClassId'],
            baseClassId: data['originalClassId'],
            title: data['className'],
            time: data['newTime'],
            location: data['newLocation'],
            instructor: data['instructor'],
            type: ClassType.lecture, // Default type
            isRecurring: false,
            date: (data['newDate'] as Timestamp).toDate(),
            teacherUid: data['teacherUid'],
            classroomId: data['classroomId'],
            classroomName: data['classroomName'],
            classCode: data['classCode'],
          );
          rescheduledClassList.add(originalClass);
        } catch (e) {
          print('Error processing rescheduled class: $e');
        }
      }

      // Filter out past classes for today
      final currentTime = TimeOfDay.fromDateTime(now);
      final filteredTodayClasses = todayClasses.where((classEvent) {
        final classTime = _parseTime(classEvent.time);
        return classTime != null && _isTimeAfter(classTime, currentTime);
      }).toList();

      setState(() {
        _todayClasses = filteredTodayClasses;
        _tomorrowClasses = tomorrowClasses;
        _rescheduledClasses = rescheduledClassList;
        _isLoading = false;

        if (_todayClasses.isNotEmpty) {
          _displayTitle = "Today's Classes";
        } else if (_tomorrowClasses.isNotEmpty) {
          _displayTitle = "Tomorrow's Classes";
        } else if (_rescheduledClasses.isNotEmpty) {
          _displayTitle = "Rescheduled Classes";
        } else {
          _displayTitle = "My Classes";
        }
      });

    } catch (e) {
      print('Error loading classes: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Role-based action buttons - Students cannot edit/delete classes
  Widget _buildRoleBasedActions() {
    if (widget.userRole == 'Teacher' || widget.userRole == 'CR') {
      return Row(
        children: [
          Expanded(
            child: _buildActionCard(
              icon: Icons.add_circle,
              title: 'Create Classroom',
              color: Colors.green,
              onTap: () {
                // Navigate to create classroom
                // This will be handled by the parent widget
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionCard(
              icon: Icons.group_add,
              title: 'Add Classroom',
              color: Colors.blue,
              onTap: () {
                // Navigate to add classroom
                // This will be handled by the parent widget
              },
            ),
          ),
        ],
      );
    } else if (widget.userRole == 'Student') {
      return _buildActionCard(
        icon: Icons.group_add,
        title: 'Add Classroom',
        color: Colors.blue,
        onTap: () {
          // Navigate to add classroom
          // This will be handled by the parent widget
        },
      );
    } else if (widget.userRole == null) {
      return _buildActionCard(
        icon: Icons.person,
        title: 'Select Role',
        color: Colors.orange,
        onTap: () {
          // Navigate to role selection
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => RoleSelectionScreen()),
          );
        },
      );
    } else {
      // If role is selected but not teacher/CR, e.g., 'Student', and we want to show nothing
      return const SizedBox.shrink(); // Don't show any card
    }
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.2),
                radius: 20,
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TimeOfDay? _parseTime(String timeString) {
    try {
      final timePart = timeString.split(' - ').first;
      final format = timePart.contains('AM') || timePart.contains('PM')
          ? DateFormat('h:mm a')
          : DateFormat('HH:mm');
      final dateTime = format.parse(timePart);
      return TimeOfDay.fromDateTime(dateTime);
    } catch (e) {
      print('Error parsing time: $timeString - $e');
      return null;
    }
  }

  bool _isTimeAfter(TimeOfDay classTime, TimeOfDay currentTime) {
    if (classTime.hour > currentTime.hour) return true;
    if (classTime.hour == currentTime.hour && classTime.minute > currentTime.minute) return true;
    return false;
  }

  List<ClassEvent> get _displayClasses {
    if (_todayClasses.isNotEmpty) return _todayClasses;
    if (_tomorrowClasses.isNotEmpty) return _tomorrowClasses;
    if (_rescheduledClasses.isNotEmpty) return _rescheduledClasses;
    return [];
  }

  String get _classCountText {
    if (_todayClasses.isNotEmpty) return '${_todayClasses.length} ${_todayClasses.length == 1 ? 'Class' : 'Classes'}';
    if (_tomorrowClasses.isNotEmpty) return '${_tomorrowClasses.length} ${_tomorrowClasses.length == 1 ? 'Class' : 'Classes'}';
    if (_rescheduledClasses.isNotEmpty) return '${_rescheduledClasses.length} Rescheduled';
    return 'No Classes';
  }

  Color get _classCountColor {
    if (_todayClasses.isNotEmpty) return Colors.blue;
    if (_tomorrowClasses.isNotEmpty) return Colors.orange;
    if (_rescheduledClasses.isNotEmpty) return Colors.purple;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          _buildWelcomeSection(user),
          const SizedBox(height: 24),

          // Role-based Actions
          _buildRoleBasedActions(),
          const SizedBox(height: 24),

          // Rescheduled Classes Card (if any)
          if (_rescheduledClasses.isNotEmpty) ...[
            _buildRescheduledClassesCard(),
            const SizedBox(height: 24),
          ],

          // Classes Card
          _buildClassesCard(),
          const SizedBox(height: 24),

          // Quick Actions
          _buildQuickActions(),
          const SizedBox(height: 24),

          // Recent Notifications
          _buildNotificationsCard(),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(User? user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello, ${user?.displayName?.split(' ').first ?? 'User'}! 👋',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isLoading
              ? 'Loading your schedule...'
              : _getGreetingMessage(),
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),

        // Role badge
        if (widget.userRole != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _getRoleColor(widget.userRole!).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _getRoleColor(widget.userRole!)),
            ),
            child: Text(
              widget.userRole!,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: _getRoleColor(widget.userRole!),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],

        // Date and time indicator
        if (!_isLoading) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, MMMM d').format(DateTime.now()),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRescheduledClassesCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "📅 Rescheduled Classes",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  label: Text(
                    '${_rescheduledClasses.length} Updated',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._rescheduledClasses.map((classEvent) => _buildRescheduledClassItem(classEvent)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRescheduledClassItem(ClassEvent classEvent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.update, color: Colors.purple, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  classEvent.title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${classEvent.time} • ${classEvent.location}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  DateFormat('MMM d, yyyy').format(classEvent.date),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.purple,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Teacher':
        return Colors.red;
      case 'CR':
        return Colors.orange;
      case 'Student':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getGreetingMessage() {
    if (_todayClasses.isNotEmpty) {
      return 'You have ${_todayClasses.length} ${_todayClasses.length == 1 ? 'class' : 'classes'} today.';
    } else if (_tomorrowClasses.isNotEmpty) {
      return 'No more classes today. ${_tomorrowClasses.length} ${_tomorrowClasses.length == 1 ? 'class' : 'classes'} scheduled for tomorrow.';
    } else if (_rescheduledClasses.isNotEmpty) {
      return 'You have ${_rescheduledClasses.length} rescheduled ${_rescheduledClasses.length == 1 ? 'class' : 'classes'}.';
    } else {
      return 'No upcoming classes. Join a classroom to see classes!';
    }
  }

  Widget _buildClassesCard() {
    if (_isLoading) {
      return _buildLoadingCard();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _displayTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  label: Text(
                    _classCountText,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: _classCountColor,
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_displayClasses.isEmpty)
              _buildEmptyClassesState()
            else
              ..._buildClassList(),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  widget.onNavigate(1); // Navigate to Schedule screen (index 1)
                },
                icon: const Icon(Icons.schedule, size: 20),
                label: Text(
                  'View Full Schedule',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 150,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Container(
                  width: 80,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildClassItemShimmer(),
            const Divider(),
            _buildClassItemShimmer(),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassItemShimmer() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 180,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyClassesState() {
    return Column(
      children: [
        Icon(
          Icons.school_outlined,
          size: 64,
          color: Colors.grey[300],
        ),
        const SizedBox(height: 16),
        Text(
          'No upcoming classes',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Join a classroom to see scheduled classes',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildClassList() {
    return _displayClasses.map((classEvent) {
      return Column(
        children: [
          _buildClassItem(classEvent),
          if (_displayClasses.indexOf(classEvent) != _displayClasses.length - 1)
            const Divider(),
        ],
      );
    }).toList();
  }

  Widget _buildClassItem(ClassEvent classEvent) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: _getColorForType(classEvent.type).withOpacity(0.2),
        child: Icon(_getIconForType(classEvent.type), color: _getColorForType(classEvent.type)),
      ),
      title: Text(
        classEvent.title,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '${classEvent.time} • ${classEvent.location}',
        style: GoogleFonts.poppins(),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        widget.onNavigate(1); // Navigate to Schedule screen (index 1)
      },
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionCard(
            icon: Icons.add,
            title: 'Add Class',
            color: Colors.green,
            onTap: () {
              widget.onNavigate(1); // Navigate to Schedule screen (index 1)
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickActionCard(
            icon: Icons.assignment,
            title: 'Assignments',
            color: Colors.orange,
            onTap: () {
              widget.onNavigate(2); // Navigate to Assignments screen (index 2)
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickActionCard(
            icon: Icons.notifications,
            title: 'Notifications',
            color: Colors.purple,
            onTap: () {
              widget.onNavigate(3); // Navigate to Notifications screen (index 3)
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.2),
                radius: 20,
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Recent Notifications",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  label: Text(
                    '3 New',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildNotificationItem('Class Rescheduled', 'Math class moved to Room 305', Icons.schedule, Colors.blue),
            const Divider(),
            _buildNotificationItem('New Assignment', 'CS Assignment 3 posted', Icons.assignment, Colors.orange),
            const Divider(),
            _buildNotificationItem('Test Reminder', 'Literature test this Friday', Icons.quiz, Colors.red),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  widget.onNavigate(3); // Navigate to Notifications screen (index 3)
                },
                child: Text(
                  'View All Notifications',
                  style: GoogleFonts.poppins(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(String title, String subtitle, IconData icon, Color color) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.2),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: GoogleFonts.poppins()),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    );
  }

  Color _getColorForType(ClassType type) {
    switch (type) {
      case ClassType.lecture:
        return Colors.blue;
      case ClassType.lab:
        return Colors.green;
      case ClassType.tutorial:
        return Colors.orange;
      case ClassType.discussion:
        return Colors.purple;
      case ClassType.seminar:
        return Colors.teal;
    }
  }

  IconData _getIconForType(ClassType type) {
    switch (type) {
      case ClassType.lecture:
        return Icons.school;
      case ClassType.lab:
        return Icons.computer;
      case ClassType.tutorial:
        return Icons.group;
      case ClassType.discussion:
        return Icons.forum;
      case ClassType.seminar:
        return Icons.record_voice_over;
    }
  }
}