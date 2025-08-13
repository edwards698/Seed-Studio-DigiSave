import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationHistoryScreen extends StatefulWidget {
  final List<Map<String, String>> notifications;

  const NotificationHistoryScreen({Key? key, required this.notifications})
      : super(key: key);

  @override
  State<NotificationHistoryScreen> createState() =>
      _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  String _selectedFilter = 'All'; // All, Mobile App, Wio Terminal, Seed Studio
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
    // Filter notifications based on selected filter
    List<Map<String, String>> filteredNotifications;
    if (_selectedFilter == 'All') {
      filteredNotifications = widget.notifications;
    } else if (_selectedFilter == 'Mobile App') {
      filteredNotifications = widget.notifications.where((notification) {
        final device = notification['device'] ?? '';
        return device == 'Mobile App';
      }).toList();
    } else if (_selectedFilter == 'Wio Terminal') {
      filteredNotifications = widget.notifications.where((notification) {
        final device = notification['device'] ?? '';
        // Any device that's not 'Mobile App' is considered terminal
        return device != 'Mobile App' && device.isNotEmpty;
      }).toList();
    } else if (_selectedFilter == 'Seed Studio') {
      filteredNotifications = widget.notifications.where((notification) {
        final device = notification['device'] ?? '';
        // Filter for Seed Studio specific notifications
        return device.contains('Seed') || device.contains('Studio');
      }).toList();
    } else {
      filteredNotifications = widget.notifications;
    }

    // Debug logging to see what devices we have
    if (widget.notifications.isNotEmpty) {
      print("=== Notification History Debug ===");
      print("Selected filter: $_selectedFilter");
      print("Total notifications: ${widget.notifications.length}");
      print("Filtered notifications: ${filteredNotifications.length}");
      for (var notification in widget.notifications) {
        print(
            "Device: '${notification['device']}', Title: '${notification['title']}'");
      }
      print("=== End Debug ===");
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // Remove back button
        title: AnimatedOpacity(
          opacity: _showTitle ? 1.0 : 0.0,
          duration: Duration(milliseconds: 200),
          child: Text(
            'Notifications',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
      ),
      body: filteredNotifications.isEmpty
          ? Column(
              children: [
                // Large Notifications title that disappears when scrolling
                AnimatedOpacity(
                  opacity: _showTitle ? 0.0 : 1.0,
                  duration: Duration(milliseconds: 200),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    color: Colors.white,
                    child: Text(
                      'Notifications',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                // Toggle filter at the top
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All', Icons.notifications),
                        const SizedBox(width: 8),
                        _buildFilterChip('Mobile App', Icons.smartphone),
                        const SizedBox(width: 8),
                        _buildFilterChip('Wio Terminal', Icons.computer),
                        const SizedBox(width: 8),
                        _buildFilterChip('Seed Studio', Icons.developer_board),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _selectedFilter == 'All'
                          ? 'No notifications yet'
                          : 'No $_selectedFilter notifications',
                      style: GoogleFonts.poppins(color: Colors.black),
                    ),
                  ),
                ),
              ],
            )
          : CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Large title section
                SliverToBoxAdapter(
                  child: AnimatedOpacity(
                    opacity: _showTitle ? 0.0 : 1.0,
                    duration: Duration(milliseconds: 200),
                    child: Container(
                      width: double.infinity,
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      color: Colors.white,
                      child: Text(
                        'Notifications',
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
                // Filter chips section
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All', Icons.notifications),
                          const SizedBox(width: 8),
                          _buildFilterChip('Mobile App', Icons.smartphone),
                          const SizedBox(width: 8),
                          _buildFilterChip('Wio Terminal', Icons.computer),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                              'Seed Studio', Icons.developer_board),
                        ],
                      ),
                    ),
                  ),
                ),
                // Notifications list
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final notification = filteredNotifications[index];
                      // Get device and type information
                      final device = notification['device'] ?? '';
                      final amount = notification['amount'] ?? '';

                      // Determine which icon to show based on device
                      String deviceIcon;
                      if (device == 'Mobile App') {
                        deviceIcon =
                            'assets/icons/smartphone.png'; // Mobile phone icon
                      } else {
                        deviceIcon =
                            'assets/icons/terminal.png'; // Terminal icon for terminal transactions
                      }

                      // Try to parse details from the body string if possible
                      final body = notification['body'] ?? '';
                      String time = '';
                      final timeMatch =
                          RegExp(r'Time: ([^|]+)').firstMatch(body);
                      if (timeMatch != null) {
                        String rawTime = timeMatch.group(1)?.trim() ?? '';
                        try {
                          // Parse the ISO timestamp
                          DateTime dateTime = DateTime.parse(rawTime);
                          DateTime now = DateTime.now();

                          // Calculate difference
                          Duration difference = now.difference(dateTime);

                          if (difference.inMinutes < 1) {
                            time = 'Just now';
                          } else if (difference.inMinutes < 60) {
                            time = '${difference.inMinutes}m ago';
                          } else if (difference.inHours < 24) {
                            time = '${difference.inHours}h ago';
                          } else if (difference.inDays < 7) {
                            time = '${difference.inDays}d ago';
                          } else {
                            // Format as readable date for older timestamps
                            time =
                                '${dateTime.day}/${dateTime.month}/${dateTime.year}';
                          }
                        } catch (e) {
                          // If parsing fails, show original time
                          time = rawTime;
                        }
                      }

                      return ListTile(
                        tileColor: Colors.white,
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[300]!.withOpacity(0.5),
                          radius: 20,
                          child: Image.asset(
                            deviceIcon,
                            width: 24,
                            height: 24,
                            fit: BoxFit.contain, // Make sure icon shows fully
                          ),
                        ),
                        title: Text(
                          notification['title'] ?? '',
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (amount.isNotEmpty)
                              Text(
                                'Amount: \$$amount',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                            if (device.isNotEmpty)
                              Container(
                                margin: EdgeInsets.only(top: 4),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  device == 'Mobile App'
                                      ? '📱 Mobile App'
                                      : '💻 Wio Terminal',
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600]),
                                ),
                              ),
                            if (time.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  'Time: $time',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                    childCount: filteredNotifications.length,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
