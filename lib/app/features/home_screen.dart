import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edunotify/app/features/assignment_screen.dart';
import 'package:edunotify/app/features/notification_screen.dart';
import 'package:edunotify/app/features/settings_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../auth/login_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(onNavigate: _navigateToPage),
      const ScheduleScreen(),
      const AssignmentScreen(),
      const NotificationScreen(),
      SettingsScreen(),
    ];
  }

  void _navigateToPage(int index) {
    setState(() {
      _currentIndex = index;
    });
  }
  @override
  Widget build(BuildContext context) {
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
            const Divider(),
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
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final GoToPageCallback onNavigate;
  const DashboardScreen({super.key, required this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<ClassEvent> _todayClasses = [];
  List<ClassEvent> _tomorrowClasses = [];
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

      // Load today's classes
      final todaySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('classes')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .where('date', isLessThan: Timestamp.fromDate(today.add(const Duration(days: 1))))
          .orderBy('date')
          .get();

      // Load tomorrow's classes
      final tomorrowSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('classes')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(tomorrow))
          .where('date', isLessThan: Timestamp.fromDate(tomorrow.add(const Duration(days: 1))))
          .orderBy('date')
          .get();

      List<ClassEvent> todayClasses = [];
      List<ClassEvent> tomorrowClasses = [];

      // Process today's classes
      for (final doc in todaySnapshot.docs) {
        final classEvent = ClassEvent.fromMap(doc.data());
        todayClasses.add(classEvent);
      }

      // Process tomorrow's classes
      for (final doc in tomorrowSnapshot.docs) {
        final classEvent = ClassEvent.fromMap(doc.data());
        tomorrowClasses.add(classEvent);
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
        _isLoading = false;

        // Determine what to display
        if (_todayClasses.isNotEmpty) {
          _displayTitle = "Today's Classes";
        } else if (_tomorrowClasses.isNotEmpty) {
          _displayTitle = "Tomorrow's Classes";
        } else {
          _displayTitle = "Upcoming Classes";
        }
      });
    } catch (e) {
      print('Error loading classes: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  TimeOfDay? _parseTime(String timeString) {
    try {
      // Handle formats like "9:00 AM - 10:30 AM" or "14:00 - 15:30"
      final timePart = timeString.split(' - ').first;
      final format = timePart.contains('AM') || timePart.contains('PM')
          ? DateFormat('h:mm a')
          : DateFormat('HH:mm');
      final dateTime = format.parse(timePart);
      return TimeOfDay.fromDateTime(dateTime);
    } catch (e) {
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
    return [];
  }

  String get _classCountText {
    if (_todayClasses.isNotEmpty) return '${_todayClasses.length} ${_todayClasses.length == 1 ? 'Class' : 'Classes'}';
    if (_tomorrowClasses.isNotEmpty) return '${_tomorrowClasses.length} ${_tomorrowClasses.length == 1 ? 'Class' : 'Classes'}';
    return 'No Classes';
  }

  Color get _classCountColor {
    if (_todayClasses.isNotEmpty) return Colors.blue;
    if (_tomorrowClasses.isNotEmpty) return Colors.orange;
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

  String _getGreetingMessage() {
    if (_todayClasses.isNotEmpty) {
      return 'You have ${_todayClasses.length} ${_todayClasses.length == 1 ? 'class' : 'classes'} today.';
    } else if (_tomorrowClasses.isNotEmpty) {
      return 'No more classes today. ${_tomorrowClasses.length} ${_tomorrowClasses.length == 1 ? 'class' : 'classes'} scheduled for tomorrow.';
    } else {
      return 'No upcoming classes. Add some classes to your schedule!';
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
          'Add classes to your schedule to see them here',
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
              // Navigate to assignments
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationScreen(),
                    ),
                  );
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

// Add these classes at the bottom of the file (same as in schedule_screen.dart)
class ClassEvent {
  final String id;
  final String baseClassId;
  final String title;
  final String time;
  final String location;
  final String instructor;
  final ClassType type;
  final bool isRecurring;

  ClassEvent({
    required this.id,
    required this.baseClassId,
    required this.title,
    required this.time,
    required this.location,
    required this.instructor,
    required this.type,
    this.isRecurring = false,
  });

  ClassEvent copyWith({
    String? id,
    String? baseClassId,
    String? title,
    String? time,
    String? location,
    String? instructor,
    ClassType? type,
    bool? isRecurring,
  }) {
    return ClassEvent(
      id: id ?? this.id,
      baseClassId: baseClassId ?? this.baseClassId,
      title: title ?? this.title,
      time: time ?? this.time,
      location: location ?? this.location,
      instructor: instructor ?? this.instructor,
      type: type ?? this.type,
      isRecurring: isRecurring ?? this.isRecurring,
    );
  }

  Map<String, dynamic> toMap(DateTime date) {
    return {
      'id': id,
      'baseClassId': baseClassId,
      'title': title,
      'time': time,
      'location': location,
      'instructor': instructor,
      'type': type.index,
      'date': Timestamp.fromDate(date),
      'isRecurring': isRecurring,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory ClassEvent.fromMap(Map<String, dynamic> map) {
    return ClassEvent(
      id: map['id'] ?? '',
      baseClassId: map['baseClassId'] ?? map['id']?.split('_')[0] ?? '',
      title: map['title'] ?? '',
      time: map['time'] ?? '',
      location: map['location'] ?? '',
      instructor: map['instructor'] ?? '',
      type: ClassType.values[map['type'] ?? 0],
      isRecurring: map['isRecurring'] ?? false,
    );
  }
}

enum ClassType {
  lecture,
  lab,
  tutorial,
  discussion,
  seminar,
}