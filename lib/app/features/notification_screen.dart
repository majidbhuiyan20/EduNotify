import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<AppNotification> _notifications = [];
  final List<AppNotification> _readNotifications = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription? _notificationsSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _setupNotificationsListener();
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _setupNotificationsListener() {
    final user = _auth.currentUser;
    if (user == null) return;

    _notificationsSubscription = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _processNotifications(snapshot.docs);
    });
  }

  void _processNotifications(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    List<AppNotification> unreadNotifications = [];
    List<AppNotification> readNotifications = [];

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;

      // Check if notification should be expired
      if (_shouldExpireNotification(data, now)) {
        _markNotificationAsInactive(doc.id);
        continue;
      }

      final notification = _createNotificationFromData(data, doc.id);

      if (notification.isRead) {
        readNotifications.add(notification);
      } else {
        unreadNotifications.add(notification);
      }
    }

    if (mounted) {
      setState(() {
        _notifications.clear();
        _notifications.addAll(unreadNotifications);
        _readNotifications.clear();
        _readNotifications.addAll(readNotifications);
      });
    }
  }

  bool _shouldExpireNotification(Map<String, dynamic> data, DateTime now) {
    final type = data['type'] as String?;
    final createdAt = (data['createdAt'] as Timestamp).toDate();

    if (type == 'assignment') {
      final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
      if (dueDate != null && dueDate.isBefore(now)) {
        return true;
      }
    }
    else if (type == 'class_reschedule') {
      final classDate = (data['classDate'] as Timestamp?)?.toDate();
      if (classDate != null && classDate.isBefore(now)) {
        return true;
      }
    }

    // Keep other notifications for 30 days
    return createdAt.isBefore(now.subtract(const Duration(days: 30)));
  }

  Future<void> _markNotificationAsInactive(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking notification as inactive: $e');
    }
  }

  AppNotification _createNotificationFromData(Map<String, dynamic> data, String id) {
    final typeString = data['type'] as String? ?? 'general';
    final priorityString = data['priority'] as String? ?? 'medium';

    return AppNotification(
      id: id,
      title: data['title'] as String? ?? 'Notification',
      message: data['message'] as String? ?? '',
      type: _parseNotificationType(typeString),
      timestamp: (data['createdAt'] as Timestamp).toDate(),
      isRead: data['isRead'] as bool? ?? false,
      priority: _parsePriority(priorityString),
      relatedId: data['relatedId'] as String?,
      classroomId: data['classroomId'] as String?,
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      classDate: (data['classDate'] as Timestamp?)?.toDate(),
    );
  }

  NotificationType _parseNotificationType(String type) {
    switch (type) {
      case 'assignment':
        return NotificationType.assignment;
      case 'class_reschedule':
        return NotificationType.classUpdate;
      case 'test':
        return NotificationType.test;
      case 'grade':
        return NotificationType.grade;
      case 'reminder':
        return NotificationType.reminder;
      case 'event':
        return NotificationType.event;
      default:
        return NotificationType.general;
    }
  }

  Priority _parsePriority(String priority) {
    switch (priority) {
      case 'high':
        return Priority.high;
      case 'low':
        return Priority.low;
      default:
        return Priority.medium;
    }
  }

  Future<void> _markAsRead(AppNotification notification) async {
    try {
      await _firestore.collection('notifications').doc(notification.id).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking notification as read: $e');
      // Fallback: update locally
      setState(() {
        _notifications.remove(notification);
        _readNotifications.add(notification.copyWith(isRead: true));
      });
    }
  }

  Future<void> _markAllAsRead() async {
    if (_notifications.isEmpty) return;

    try {
      final batch = _firestore.batch();
      for (final notification in _notifications) {
        final docRef = _firestore.collection('notifications').doc(notification.id);
        batch.update(docRef, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      print('Error marking all as read: $e');
      // Fallback: update locally
      setState(() {
        _readNotifications.addAll(_notifications.map((n) => n.copyWith(isRead: true)));
        _notifications.clear();
      });
    }
  }

  Future<void> _deleteNotification(AppNotification notification, bool isUnread) async {
    try {
      await _markNotificationAsInactive(notification.id);
    } catch (e) {
      print('Error deleting notification: $e');
      // Fallback: remove locally
      setState(() {
        if (isUnread) {
          _notifications.remove(notification);
        } else {
          _readNotifications.remove(notification);
        }
      });
    }
  }

  Future<void> _clearAllRead() async {
    if (_readNotifications.isEmpty) return;

    try {
      final batch = _firestore.batch();
      for (final notification in _readNotifications) {
        final docRef = _firestore.collection('notifications').doc(notification.id);
        batch.update(docRef, {
          'isActive': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      print('Error clearing all read: $e');
      // Fallback: clear locally
      setState(() {
        _readNotifications.clear();
      });
    }
  }

  void _showNotificationDetails(AppNotification notification) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => NotificationDetailsBottomSheet(notification: notification),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.mark_email_read),
              tooltip: 'Mark all as read',
            ),
          if (_readNotifications.isNotEmpty)
            IconButton(
              onPressed: _clearAllRead,
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear all read',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Badge(
                isLabelVisible: _notifications.isNotEmpty,
                label: Text(_notifications.length.toString()),
                child: Text(
                  'Unread',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
              ),
            ),
            Tab(
              child: Text(
                'Read',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Unread Notifications Tab
          _notifications.isEmpty
              ? _buildEmptyState(
            'No unread notifications',
            Icons.notifications_none,
            'You\'re all caught up!',
          )
              : RefreshIndicator(
            onRefresh: () async {
              // Force reload by resetting the listener
              _setupNotificationsListener();
              return Future.delayed(const Duration(seconds: 1));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                return NotificationCard(
                  notification: _notifications[index],
                  onTap: () => _showNotificationDetails(_notifications[index]),
                  onRead: () => _markAsRead(_notifications[index]),
                  onDelete: () => _deleteNotification(_notifications[index], true),
                );
              },
            ),
          ),

          // Read Notifications Tab
          _readNotifications.isEmpty
              ? _buildEmptyState(
            'No read notifications',
            Icons.history,
            'Notifications you\'ve read will appear here',
          )
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _readNotifications.length,
            itemBuilder: (context, index) {
              return NotificationCard(
                notification: _readNotifications[index],
                onTap: () => _showNotificationDetails(_readNotifications[index]),
                onDelete: () => _deleteNotification(_readNotifications[index], false),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, IconData icon, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback? onRead;
  final VoidCallback onDelete;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
    this.onRead,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final timeAgo = _getTimeAgo(notification.timestamp);
    final hasDueDate = notification.dueDate != null;
    final hasClassDate = notification.classDate != null;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) => onDelete(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 1,
        color: notification.isRead ? Colors.grey[50] : Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Notification Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getNotificationColor(notification.type).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getNotificationIcon(notification.type),
                    color: _getNotificationColor(notification.type),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Notification Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and Priority
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: notification.isRead ? Colors.grey[700] : Colors.blue[800],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (notification.priority == Priority.high)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Important',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Message
                      Text(
                        notification.message,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Due Date or Class Date (if available)
                      if (hasDueDate || hasClassDate) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: _getNotificationColor(notification.type),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _getDateInfo(notification),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: _getNotificationColor(notification.type),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 8),
                      // Time and Actions
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            timeAgo,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                          const Spacer(),
                          if (onRead != null && !notification.isRead)
                            TextButton(
                              onPressed: onRead,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: Size.zero,
                              ),
                              child: Text(
                                'Mark as read',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return DateFormat('MMM d').format(timestamp);
  }

  String _getDateInfo(AppNotification notification) {
    if (notification.dueDate != null) {
      return 'Due: ${DateFormat('MMM d, yyyy').format(notification.dueDate!)}';
    } else if (notification.classDate != null) {
      return 'Class: ${DateFormat('MMM d, yyyy').format(notification.classDate!)}';
    }
    return '';
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.classUpdate:
        return Icons.schedule;
      case NotificationType.assignment:
        return Icons.assignment;
      case NotificationType.test:
        return Icons.quiz;
      case NotificationType.grade:
        return Icons.grade;
      case NotificationType.reminder:
        return Icons.notifications;
      case NotificationType.event:
        return Icons.event;
      case NotificationType.general:
        return Icons.info;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.classUpdate:
        return Colors.blue;
      case NotificationType.assignment:
        return Colors.orange;
      case NotificationType.test:
        return Colors.red;
      case NotificationType.grade:
        return Colors.green;
      case NotificationType.reminder:
        return Colors.purple;
      case NotificationType.event:
        return Colors.teal;
      case NotificationType.general:
        return Colors.grey;
    }
  }
}

class NotificationDetailsBottomSheet extends StatelessWidget {
  final AppNotification notification;

  const NotificationDetailsBottomSheet({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    final hasDueDate = notification.dueDate != null;
    final hasClassDate = notification.classDate != null;

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
          // Header with Icon and Title
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getNotificationColor(notification.type).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getNotificationIcon(notification.type),
                  color: _getNotificationColor(notification.type),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  notification.title,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Timestamp
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                DateFormat('MMM d, yyyy • h:mm a').format(notification.timestamp),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),

          // Due Date or Class Date
          if (hasDueDate || hasClassDate) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: _getNotificationColor(notification.type)),
                const SizedBox(width: 4),
                Text(
                  _getDateInfo(notification),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: _getNotificationColor(notification.type),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),
          // Message
          Text(
            'Message',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            notification.message,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          // Notification Type
          Text(
            'Type',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getNotificationColor(notification.type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _getNotificationTypeText(notification.type),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _getNotificationColor(notification.type),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Action Buttons
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Close',
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
    );
  }

  String _getDateInfo(AppNotification notification) {
    if (notification.dueDate != null) {
      return 'Due Date: ${DateFormat('EEEE, MMMM d, yyyy').format(notification.dueDate!)}';
    } else if (notification.classDate != null) {
      return 'Class Date: ${DateFormat('EEEE, MMMM d, yyyy').format(notification.classDate!)}';
    }
    return '';
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.classUpdate:
        return Icons.schedule;
      case NotificationType.assignment:
        return Icons.assignment;
      case NotificationType.test:
        return Icons.quiz;
      case NotificationType.grade:
        return Icons.grade;
      case NotificationType.reminder:
        return Icons.notifications;
      case NotificationType.event:
        return Icons.event;
      case NotificationType.general:
        return Icons.info;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.classUpdate:
        return Colors.blue;
      case NotificationType.assignment:
        return Colors.orange;
      case NotificationType.test:
        return Colors.red;
      case NotificationType.grade:
        return Colors.green;
      case NotificationType.reminder:
        return Colors.purple;
      case NotificationType.event:
        return Colors.teal;
      case NotificationType.general:
        return Colors.grey;
    }
  }

  String _getNotificationTypeText(NotificationType type) {
    switch (type) {
      case NotificationType.classUpdate:
        return 'Class Update';
      case NotificationType.assignment:
        return 'Assignment';
      case NotificationType.test:
        return 'Test';
      case NotificationType.grade:
        return 'Grade';
      case NotificationType.reminder:
        return 'Reminder';
      case NotificationType.event:
        return 'Event';
      case NotificationType.general:
        return 'General';
    }
  }
}

// Data Models
enum NotificationType {
  classUpdate,
  assignment,
  test,
  grade,
  reminder,
  event,
  general,
}

enum Priority { low, medium, high }

class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;
  final Priority priority;
  final String? relatedId;
  final String? classroomId;
  final DateTime? dueDate;
  final DateTime? classDate;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    required this.isRead,
    required this.priority,
    this.relatedId,
    this.classroomId,
    this.dueDate,
    this.classDate,
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    DateTime? timestamp,
    bool? isRead,
    Priority? priority,
    String? relatedId,
    String? classroomId,
    DateTime? dueDate,
    DateTime? classDate,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      priority: priority ?? this.priority,
      relatedId: relatedId ?? this.relatedId,
      classroomId: classroomId ?? this.classroomId,
      dueDate: dueDate ?? this.dueDate,
      classDate: classDate ?? this.classDate,
    );
  }
}