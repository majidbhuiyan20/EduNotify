import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _darkMode = false;
  bool _autoSync = true;
  String _selectedLanguage = 'English';
  String _selectedTheme = 'System Default';

  final List<String> _languages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Chinese',
    'Japanese',
    'Arabic'
  ];

  final List<String> _themes = [
    'System Default',
    'Light',
    'Dark'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            _buildProfileSection(),
            const SizedBox(height: 24),

            // Notification Settings
            _buildSectionHeader('Notifications'),
            _buildSettingCard(
              children: [
                _buildSwitchSetting(
                  title: 'Enable Notifications',
                  value: _notificationsEnabled,
                  onChanged: (value) => setState(() => _notificationsEnabled = value),
                  icon: Icons.notifications_active,
                ),
                if (_notificationsEnabled) ...[
                  const Divider(height: 1),
                  _buildSwitchSetting(
                    title: 'Email Notifications',
                    value: _emailNotifications,
                    onChanged: (value) => setState(() => _emailNotifications = value),
                    icon: Icons.email,
                  ),
                  const Divider(height: 1),
                  _buildSwitchSetting(
                    title: 'Push Notifications',
                    value: _pushNotifications,
                    onChanged: (value) => setState(() => _pushNotifications = value),
                    icon: Icons.notification_important,
                  ),
                  const Divider(height: 1),
                  _buildSwitchSetting(
                    title: 'Sound',
                    value: _soundEnabled,
                    onChanged: (value) => setState(() => _soundEnabled = value),
                    icon: Icons.volume_up,
                  ),
                  const Divider(height: 1),
                  _buildSwitchSetting(
                    title: 'Vibration',
                    value: _vibrationEnabled,
                    onChanged: (value) => setState(() => _vibrationEnabled = value),
                    icon: Icons.vibration,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            // Appearance Settings
            _buildSectionHeader('Appearance'),
            _buildSettingCard(
              children: [
                _buildDropdownSetting(
                  title: 'Theme',
                  value: _selectedTheme,
                  items: _themes,
                  onChanged: (value) => setState(() => _selectedTheme = value!),
                  icon: Icons.color_lens,
                ),
                const Divider(height: 1),
                _buildSwitchSetting(
                  title: 'Dark Mode',
                  value: _darkMode,
                  onChanged: (value) => setState(() => _darkMode = value),
                  icon: Icons.dark_mode,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // General Settings
            _buildSectionHeader('General'),
            _buildSettingCard(
              children: [
                _buildDropdownSetting(
                  title: 'Language',
                  value: _selectedLanguage,
                  items: _languages,
                  onChanged: (value) => setState(() => _selectedLanguage = value!),
                  icon: Icons.language,
                ),
                const Divider(height: 1),
                _buildSwitchSetting(
                  title: 'Auto Sync',
                  value: _autoSync,
                  onChanged: (value) => setState(() => _autoSync = value),
                  icon: Icons.sync,
                ),
                const Divider(height: 1),
                _buildNavigationSetting(
                  title: 'Data Usage',
                  subtitle: 'Network and storage settings',
                  onTap: () => _showDataUsageSettings(),
                  icon: Icons.data_usage,
                ),
                const Divider(height: 1),
                _buildNavigationSetting(
                  title: 'Storage',
                  subtitle: 'Manage app storage',
                  onTap: () => _showStorageSettings(),
                  icon: Icons.storage,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Account Settings
            _buildSectionHeader('Account'),
            _buildSettingCard(
              children: [
                _buildNavigationSetting(
                  title: 'Edit Profile',
                  subtitle: 'Update your personal information',
                  onTap: () => _navigateToEditProfile(),
                  icon: Icons.person,
                ),
                const Divider(height: 1),
                _buildNavigationSetting(
                  title: 'Change Password',
                  subtitle: 'Update your password',
                  onTap: () => _navigateToChangePassword(),
                  icon: Icons.lock,
                ),
                const Divider(height: 1),
                _buildNavigationSetting(
                  title: 'Privacy & Security',
                  subtitle: 'Manage your privacy settings',
                  onTap: () => _navigateToPrivacySettings(),
                  icon: Icons.security,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Support Section
            _buildSectionHeader('Support'),
            _buildSettingCard(
              children: [
                _buildNavigationSetting(
                  title: 'Help & Support',
                  subtitle: 'Get help with the app',
                  onTap: () => _showHelpSupport(),
                  icon: Icons.help_center,
                ),
                const Divider(height: 1),
                _buildNavigationSetting(
                  title: 'Send Feedback',
                  subtitle: 'Share your thoughts with us',
                  onTap: () => _sendFeedback(),
                  icon: Icons.feedback,
                ),
                const Divider(height: 1),
                _buildNavigationSetting(
                  title: 'About',
                  subtitle: 'App version and information',
                  onTap: () => _showAbout(),
                  icon: Icons.info,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // App Version
            Center(
              child: Text(
                'EduNotify v1.0.0',
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirmLogout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Log Out',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue[100],
              ),
              child: Icon(
                Icons.person,
                size: 30,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sarah Johnson',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'sarah.johnson@edu.com',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Student ID: STU2023001',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _navigateToEditProfile,
              icon: Icon(Icons.edit, color: Colors.blue[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildSettingCard({required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSwitchSetting({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue[700]),
      title: Text(
        title,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blue,
      ),
    );
  }

  Widget _buildDropdownSetting({
    required String title,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue[700]),
      title: Text(
        title,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
      ),
      trailing: DropdownButton<String>(
        value: value,
        onChanged: onChanged,
        underline: const SizedBox(),
        items: items.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNavigationSetting({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue[700]),
      title: Text(
        title,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _showDataUsageSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Data Usage Settings',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configure how the app uses your data:',
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 16),
            _buildSwitchSetting(
              title: 'Wi-Fi Only Sync',
              value: true,
              onChanged: (value) {},
              icon: Icons.wifi,
            ),
            _buildSwitchSetting(
              title: 'Low Data Mode',
              value: false,
              onChanged: (value) {},
              icon: Icons.data_saver_off,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showStorageSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Storage Management',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LinearProgressIndicator(
              value: 0.4,
              backgroundColor: Colors.grey,
              valueColor: AlwaysStoppedAnimation(Colors.blue),
            ),
            const SizedBox(height: 8),
            Text(
              '2.1 GB of 5.0 GB used',
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Clear Cache'),
              subtitle: const Text('256 MB'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Downloaded Files'),
              subtitle: const Text('1.2 GB'),
              onTap: () {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _navigateToEditProfile() {
    // Navigation to edit profile screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Navigate to Edit Profile', style: GoogleFonts.poppins())),
    );
  }

  void _navigateToChangePassword() {
    // Navigation to change password screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Navigate to Change Password', style: GoogleFonts.poppins())),
    );
  }

  void _navigateToPrivacySettings() {
    // Navigation to privacy settings screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Navigate to Privacy Settings', style: GoogleFonts.poppins())),
    );
  }

  void _showHelpSupport() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Help & Support',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSupportOption(
              icon: Icons.help_outline,
              title: 'FAQs',
              subtitle: 'Frequently asked questions',
            ),
            _buildSupportOption(
              icon: Icons.email,
              title: 'Contact Support',
              subtitle: 'Send us an email',
            ),
            _buildSupportOption(
              icon: Icons.chat,
              title: 'Live Chat',
              subtitle: 'Chat with our support team',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportOption({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue[700]),
      title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: GoogleFonts.poppins(color: Colors.grey[600])),
      onTap: () {},
    );
  }

  void _sendFeedback() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Send Feedback',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Your feedback',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Email (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'EduNotify',
      applicationVersion: 'Version 1.0.0',
      applicationIcon: const Icon(Icons.school, size: 40, color: Colors.blue),
      children: [
        const SizedBox(height: 16),
        Text(
          'EduNotify helps students stay organized with their classes, assignments, and schedules.',
          style: GoogleFonts.poppins(),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          '© 2023 EduNotify Inc. All rights reserved.',
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Log Out',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to log out of your account?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Perform logout logic
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Logged out successfully', style: GoogleFonts.poppins())),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}