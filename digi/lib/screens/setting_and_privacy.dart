import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:digi/screens/nfc_settings.dart';

class TerminalLibraryScreen extends StatefulWidget {
  const TerminalLibraryScreen({Key? key}) : super(key: key);

  @override
  State<TerminalLibraryScreen> createState() => _TerminalLibraryScreenState();
}

class _TerminalLibraryScreenState extends State<TerminalLibraryScreen> {
  late ScrollController _scrollController;
  bool _showTitle = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.offset > 50 && !_showTitle) {
      setState(() {
        _showTitle = true;
      });
    } else if (_scrollController.offset <= 50 && _showTitle) {
      setState(() {
        _showTitle = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.grey[100],
        elevation: 0,
        automaticallyImplyLeading: false, // This removes the back button
        title: AnimatedOpacity(
          opacity: _showTitle ? 1.0 : 0.0,
          duration: Duration(milliseconds: 200),
          child: Text(
            'Settings and privacy',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            children: [
              SizedBox(height: 16),

              // Large Settings title that disappears when scrolling
              AnimatedOpacity(
                opacity: _showTitle ? 0.0 : 1.0,
                duration: Duration(milliseconds: 200),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Settings and privacy',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),

              // Account section
              _buildSectionHeader('Account'),
              _buildSettingsSection([
                _buildSettingsItem(
                  icon: Icons.visibility_off,
                  title: 'Hide apps',
                  onTap: () => _showSnackBar(context, 'Hide apps'),
                ),
                _buildSettingsItem(
                  icon: Icons.backup,
                  title: 'Backup',
                  onTap: () => _showSnackBar(context, 'Backup'),
                ),
                _buildSettingsItem(
                  icon: Icons.language,
                  title: 'Language',
                  onTap: () => _showSnackBar(context, 'Language'),
                ),
              ]),

              SizedBox(height: 24),

              // Content & Privacy section
              _buildSectionHeader('Content & Privacy'),
              _buildSettingsSection([
                _buildSettingsItem(
                  icon: Icons.security,
                  title: 'Security',
                  onTap: () => _showSnackBar(context, 'Security'),
                ),
                _buildSettingsItem(
                  icon: Icons.nfc,
                  title: 'NFC Settings',
                  onTap: () => _navigateToNFCSettings(context),
                ),
                _buildSettingsItem(
                  icon: Icons.notifications,
                  title: 'Notification',
                  onTap: () => _showSnackBar(context, 'Notification'),
                ),
                _buildSettingsItem(
                  icon: Icons.person_add,
                  title: 'Invite friends',
                  onTap: () => _showSnackBar(context, 'Invite friends'),
                ),
              ]),

              SizedBox(height: 24),

              // Cache & Cellular section
              _buildSectionHeader('Cache & Cellular'),
              _buildSettingsSection([
                _buildSettingsItem(
                  icon: Icons.help_outline,
                  title: 'FAQ',
                  onTap: () => _showSnackBar(context, 'FAQ'),
                ),
                _buildSettingsItem(
                  icon: Icons.info_outline,
                  title: 'About Us',
                  onTap: () => _showSnackBar(context, 'About Us'),
                ),
              ]),

              SizedBox(height: 24),

              // Support section
              _buildSectionHeader('Support'),
              _buildSettingsSection([
                _buildSettingsItem(
                  icon: Icons.star_border,
                  title: 'Rate Us',
                  onTap: () => _showSnackBar(context, 'Rate Us'),
                ),
                _buildSettingsItem(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  onTap: () => _showSnackBar(context, 'Privacy Policy'),
                ),
              ]),

              SizedBox(height: 24),

              // Login section
              _buildSectionHeader('Login'),
              _buildSettingsSection([
                _buildSettingsItem(
                  icon: Icons.logout,
                  title: 'Logout',
                  onTap: () => _showLogoutDialog(context),
                ),
                _buildSettingsItem(
                  icon: Icons.delete_outline,
                  title: 'Delete Account',
                  titleColor: Colors.red,
                  iconColor: Colors.red,
                  onTap: () => _showDeleteAccountDialog(context),
                ),
              ]),

              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSection(List<Widget> items) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: items,
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    Color? titleColor,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Icon(
        icon,
        color: iconColor ?? Colors.grey[700],
        size: 24,
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: titleColor ?? Colors.black,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        color: Colors.grey[400],
        size: 16,
      ),
      onTap: onTap,
    );
  }

  void _showSnackBar(BuildContext context, String setting) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Opening $setting...',
          style: GoogleFonts.poppins(),
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Logout',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Logged out successfully',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Logout',
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Delete Account',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          content: Text(
            'This action cannot be undone. All your data will be permanently deleted.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Account deletion cancelled',
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Delete',
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToNFCSettings(BuildContext context) {
    // Navigate to the dedicated NFC settings screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NFCSettingsScreen(),
      ),
    );
  }
}
