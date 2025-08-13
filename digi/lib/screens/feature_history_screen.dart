import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firebase_service.dart';

class FeatureHistoryScreen extends StatefulWidget {
  final String? roomName;
  final String? deviceId;

  const FeatureHistoryScreen({
    Key? key,
    this.roomName,
    this.deviceId,
  }) : super(key: key);

  @override
  _FeatureHistoryScreenState createState() => _FeatureHistoryScreenState();
}

class _FeatureHistoryScreenState extends State<FeatureHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> history =
          await FirebaseService.getFeatureHistory(
        roomName: widget.roomName,
        deviceId: widget.deviceId,
        limit: 100,
      );

      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load history: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Feature History',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back, color: Colors.black),
        ),
        actions: [
          IconButton(
            onPressed: _loadHistory,
            icon: Icon(Icons.refresh, color: Colors.black),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter info
          if (widget.roomName != null || widget.deviceId != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filters Applied:',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  if (widget.roomName != null)
                    Text(
                      'Room: ${widget.roomName}',
                      style: GoogleFonts.poppins(color: Colors.grey[600]),
                    ),
                  if (widget.deviceId != null)
                    Text(
                      'Device: ${widget.deviceId}',
                      style: GoogleFonts.poppins(color: Colors.grey[600]),
                    ),
                ],
              ),
            ),

          // History list
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(),
                  )
                : _history.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No history found',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _history.length,
                        itemBuilder: (context, index) {
                          Map<String, dynamic> item = _history[index];
                          return _buildHistoryItem(item);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item) {
    String featureName = item['featureName'] ?? 'Unknown';
    bool newState = item['newState'] ?? false;
    bool previousState = item['previousState'] ?? false;
    String roomName = item['roomName'] ?? 'Unknown Room';
    String changeTime = item['changeTime'] ?? '';

    // Parse time
    DateTime? dateTime;
    try {
      dateTime = DateTime.parse(changeTime);
    } catch (e) {
      dateTime = null;
    }

    String timeText =
        dateTime != null ? _formatDateTime(dateTime) : 'Unknown time';

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Feature icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: newState
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              newState ? Icons.toggle_on : Icons.toggle_off,
              color: newState ? Colors.green : Colors.red,
              size: 24,
            ),
          ),
          SizedBox(width: 16),

          // Feature details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  featureName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Changed to: ${newState ? 'ON' : 'OFF'}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: newState ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Room: $roomName',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  timeText,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),

          // State indicator
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: newState ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              newState ? 'ON' : 'OFF',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    DateTime now = DateTime.now();
    Duration difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
