import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<AppNotification> _notifications = [];
  final List<AppNotification> _readNotifications = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadNotifications();
  }

  void _loadNotifications() {
    // Sample notification data
    setState(() {
      _notifications.addAll([
        AppNotification(
          id: '1',
          title: 'Class Rescheduled',
          message: 'Mathematics class has been moved to Room 305 today at 10:00 AM',
          type: NotificationType.classUpdate,
          timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
          isRead: false,
          priority: Priority.high,
        ),
        AppNotification(
          id: '2',
          title: 'New Assignment Posted',
          message: 'CS Assignment 3 has been posted. Due date: May 20, 2023',
          type: NotificationType.assignment,
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          isRead: false,
          priority: Priority.medium,
        ),
        AppNotification(
          id: '3',
          title: 'Test Reminder',
          message: 'Literature test is scheduled for this Friday. Don\'t forget to prepare!',
          type: NotificationType.test,
          timestamp: DateTime.now().subtract(const Duration(hours: 5)),
          isRead: false,
          priority: Priority.medium,
        ),
        AppNotification(
          id: '4',
          title: 'Office Hours Changed',
          message: 'Professor Smith\'s office hours have been changed to 3-5 PM on Tuesdays',
          type: NotificationType.general,
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          isRead: false,
          priority: Priority.low,
        ),
      ]);

      _readNotifications.addAll([
        AppNotification(
          id: '5',
          title: 'Grade Posted',
          message: 'Your Mathematics midterm grade has been posted to the portal',
          type: NotificationType.grade,
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
          isRead: true,
          priority: Priority.medium,
        ),
        AppNotification(
          id: '6',
          title: 'Library Book Due',
          message: 'Your library book "Introduction to Algorithms" is due tomorrow',
          type: NotificationType.reminder,
          timestamp: DateTime.now().subtract(const Duration(days: 3)),
          isRead: true,
          priority: Priority.low,
        ),
        AppNotification(
          id: '7',
          title: 'Campus Event',
          message: 'Tech Symposium happening this weekend. Register now!',
          type: NotificationType.event,
          timestamp: DateTime.now().subtract(const Duration(days: 4)),
          isRead: true,
          priority: Priority.low,
        ),
      ]);
    });
  }

  void _markAsRead(AppNotification notification) {
    setState(() {
      _notifications.remove(notification);
      _readNotifications.add(notification.copyWith(isRead: true));
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Notification marked as read'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _markAllAsRead() {
    if (_notifications.isEmpty) return;

    setState(() {
      _readNotifications.addAll(_notifications.map((n) => n.copyWith(isRead: true)));
      _notifications.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('All notifications marked as read'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _deleteNotification(AppNotification notification, bool isUnread) {
    setState(() {
      if (isUnread) {
        _notifications.remove(notification);
      } else {
        _readNotifications.remove(notification);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Notification deleted'),
        backgroundColor: Colors.blue,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              if (isUnread) {
                _notifications.add(notification);
              } else {
                _readNotifications.add(notification);
              }
            });
          },
        ),
      ),
    );
  }

  void _showNotificationDetails(AppNotification notification) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => NotificationDetailsBottomSheet(notification: notification),
    );
  }

  void _clearAllRead() {
    if (_readNotifications.isEmpty) return;

    setState(() {
      _readNotifications.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('All read notifications cleared'),
        backgroundColor: Colors.blue,
      ),
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
              // Simulate refresh
              await Future.delayed(const Duration(seconds: 1));
              setState(() {});
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

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    required this.isRead,
    required this.priority,
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    DateTime? timestamp,
    bool? isRead,
    Priority? priority,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      priority: priority ?? this.priority,
    );
  }
}