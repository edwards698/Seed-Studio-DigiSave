import 'package:digi/services/Feature_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:async';
import '../../services/firebase_service.dart';
import '../feature_history_screen.dart';

// Custom MJPEG Stream Widget
class MjpegView extends StatefulWidget {
  final String streamUrl;
  final BoxFit fit;

  const MjpegView({
    Key? key,
    required this.streamUrl,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  @override
  _MjpegViewState createState() => _MjpegViewState();
}

class _MjpegViewState extends State<MjpegView> {
  Uint8List? _currentFrame;
  bool _isLoading = true;
  bool _hasError = false;
  StreamSubscription? _streamSubscription;
  http.Client? _httpClient;
  @override
  void initState() {
    super.initState();
    _startStream();
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  void _startStream() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      _httpClient = http.Client();
      final request = http.Request('GET', Uri.parse(widget.streamUrl));
      final response = await _httpClient!.send(request);

      if (response.statusCode == 200) {
        _streamSubscription = response.stream.listen(
          _processStreamData,
          onError: (error) {
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
          },
          onDone: () {
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
          },
        );
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  List<int> _buffer = [];
  void _processStreamData(List<int> data) {
    _buffer.addAll(data);

    // Look for JPEG start and end markers
    while (_buffer.length > 4) {
      // Find JPEG start (FF D8)
      int startIndex = -1;
      for (int i = 0; i < _buffer.length - 1; i++) {
        if (_buffer[i] == 0xFF && _buffer[i + 1] == 0xD8) {
          startIndex = i;
          break;
        }
      }

      if (startIndex == -1) {
        _buffer.clear();
        break;
      }

      // Find JPEG end (FF D9)
      int endIndex = -1;
      for (int i = startIndex + 2; i < _buffer.length - 1; i++) {
        if (_buffer[i] == 0xFF && _buffer[i + 1] == 0xD9) {
          endIndex = i + 1;
          break;
        }
      }

      if (endIndex == -1) {
        // Remove data before start marker
        _buffer = _buffer.sublist(startIndex);
        break;
      }

      // Extract complete JPEG frame
      final frameData = _buffer.sublist(startIndex, endIndex + 1);
      _buffer = _buffer.sublist(endIndex + 1);

      // Update UI with new frame
      if (mounted) {
        final frameBytes = Uint8List.fromList(frameData);
        setState(() {
          _currentFrame = frameBytes;
          _isLoading = false;
          _hasError = false;
        });
      }
    }
  }

  void _stopStream() {
    _streamSubscription?.cancel();
    _httpClient?.close();
    _streamSubscription = null;
    _httpClient = null;
  }

  void _retry() {
    _stopStream();
    _startStream();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              color: Colors.white,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'Camera Offline',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Check ESP32 connection',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'URL: ${widget.streamUrl}',
              style: GoogleFonts.poppins(
                color: Colors.white60,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _retry,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoading || _currentFrame == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Colors.white,
            ),
            SizedBox(height: 16),
            Text(
              'Connecting to camera...',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Image.memory(
      _currentFrame!,
      fit: widget.fit,
      gaplessPlayback: true,
    );
  }
}

class SecurityScreen extends StatefulWidget {
  @override
  _SecurityScreenState createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool isSecured = true;
  bool isTracking = false;
  bool isMotionDetection = true;
  bool isNightMode = false;
  bool isDormancy = false;
  bool isTimeLapse = false;
  bool isCalibration = false;
  bool isLoadingFeatures = false;

  String selectedRoom = 'Bedroom';
  List<String> availableRooms = [
    'Bedroom',
    'Living Room',
    'Kitchen',
    'Office',
    'Garage',
    'Front Door',
    'Backyard',
    'Kids Room'
  ];

  // ESP32 Camera stream URL - update this with your XIAO ESP32S3's IP address
  // Replace 192.168.1.50 with your ESP32's actual IP from Serial Monitor
  String cameraStreamUrl = 'http://192.168.100.28/stream';

  // Extract base URL for other endpoints
  String get baseUrl => cameraStreamUrl.replaceAll('/stream', '');

  @override
  void initState() {
    super.initState();
    _loadFeatureStatesFromFirebase();
  }

  Future<void> _loadFeatureStatesFromFirebase() async {
    setState(() {
      isLoadingFeatures = true;
    });

    try {
      // Use room and device for docId
      String docId =
          '${selectedRoom.toLowerCase().replaceAll(' ', '_')}-xiao_esp32s3';
      Map<String, bool> featureStates = await FeatureService.getFeatureStates(
        docId: docId,
      );

      setState(() {
        isTimeLapse = featureStates['timeLapse'] ?? false;
        isTracking = featureStates['tracking'] ?? false;
        isMotionDetection = featureStates['motionDetection'] ?? true;
        isNightMode = featureStates['nightMode'] ?? false;
        isDormancy = featureStates['dormancy'] ?? false;
        isCalibration = featureStates['calibration'] ?? false;
        isLoadingFeatures = false;
      });

      print('✅ Feature states loaded from Firebase');
    } catch (e) {
      print('❌ Error loading feature states: $e');
      setState(() {
        isLoadingFeatures = false;
      });
      _showError('Failed to load feature states from Firebase');
    }
  }

  // Update a specific feature in Firebase
  Future<void> _updateFeatureInFirebase(
      String featureName, bool newValue, bool oldValue) async {
    try {
      await FirebaseService.updateFeatureState(
        featureName: featureName,
        isActive: newValue,
        roomName: selectedRoom,
        deviceId: 'xiao_esp32s3',
      );

      // Log the change
      await FirebaseService.logFeatureChange(
        featureName: featureName,
        newState: newValue,
        previousState: oldValue,
        roomName: selectedRoom,
        deviceId: 'xiao_esp32s3',
      );

      _showSuccess('$featureName ${newValue ? 'enabled' : 'disabled'}');
    } catch (e) {
      print('❌ Error updating feature in Firebase: $e');
      _showError('Failed to update $featureName');
    }
  }

  // Show success message
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Show error message
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showRoomSelection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.symmetric(vertical: 12),
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'Select Camera Room',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Spacer(),
                  // Add room button
                  IconButton(
                    onPressed: () {
                      _showAddRoomDialog();
                    },
                    icon: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            // Room list
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 20),
                itemCount: availableRooms.length,
                itemBuilder: (context, index) {
                  String room = availableRooms[index];
                  bool isSelected = room == selectedRoom;

                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue : Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getRoomIcon(room),
                          color: isSelected ? Colors.white : Colors.grey[600],
                          size: 20,
                        ),
                      ),
                      title: Text(
                        room,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? Colors.blue : Colors.black,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle,
                              color: Colors.blue, size: 24)
                          : Icon(Icons.radio_button_unchecked,
                              color: Colors.grey[400], size: 24),
                      onTap: () {
                        setState(() {
                          selectedRoom = room;
                        });
                        Navigator.pop(context);
                        // Reload features for the new room
                        _loadFeatureStatesFromFirebase();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddRoomDialog() {
    TextEditingController roomController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Add New Room',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: roomController,
              decoration: InputDecoration(
                hintText: 'Enter room name',
                hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue, width: 2),
                ),
              ),
              style: GoogleFonts.poppins(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              String newRoom = roomController.text.trim();
              if (newRoom.isNotEmpty && !availableRooms.contains(newRoom)) {
                setState(() {
                  availableRooms.add(newRoom);
                });
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close room selection sheet
                _showRoomSelection(); // Reopen room selection with new room
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Add',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCameraSettingsDialog() {
    TextEditingController ipController = TextEditingController();
    // Extract IP from current URL (format: http://IP/stream)
    String currentIP =
        cameraStreamUrl.replaceAll('http://', '').replaceAll('/stream', '');
    ipController.text = currentIP;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Camera Settings',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter XIAO ESP32S3 IP Address',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: ipController,
              decoration: InputDecoration(
                hintText: '192.168.1.50',
                hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue, width: 2),
                ),
              ),
              style: GoogleFonts.poppins(),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              String newIP = ipController.text.trim();
              if (newIP.isNotEmpty) {
                setState(() {
                  cameraStreamUrl = 'http://$newIP/stream';
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Update',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getRoomIcon(String room) {
    switch (room) {
      case 'Bedroom':
        return Icons.bed;
      case 'Living Room':
        return Icons.weekend;
      case 'Kitchen':
        return Icons.kitchen;
      case 'Office':
        return Icons.work;
      case 'Garage':
        return Icons.garage;
      case 'Front Door':
        return Icons.door_front_door;
      case 'Backyard':
        return Icons.grass;
      case 'Kids Room':
        return Icons.toys;
      default:
        return Icons.room;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, color: Colors.black),
                  ),
                  Expanded(
                    child: Text(
                      'XIAO ESP32S3',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // History button
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FeatureHistoryScreen(
                            roomName: selectedRoom,
                            deviceId: 'xiao_esp32s3',
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.history, color: Colors.black),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Camera View
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // Live camera feed from XIAO ESP32S3
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        child: MjpegView(
                          streamUrl: cameraStreamUrl,
                          fit: BoxFit.cover,
                        ),
                      ),

                      // Status indicators
                      Positioned(
                        top: 20,
                        left: 20,
                        child: Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isSecured ? Colors.green : Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                isSecured ? 'Secured' : 'Unsecured',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Camera controls
                      Positioned(
                        bottom: 20,
                        right: 20,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Camera settings button
                            GestureDetector(
                              onTap: _showCameraSettingsDialog,
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.settings,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            // Video camera button
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.videocam,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: 20),

            // Room label - clickable (aligned to left)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: _showRoomSelection,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getRoomIcon(selectedRoom),
                          color: Colors.grey[700],
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          selectedRoom,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: 30),

            // Features section
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'More features',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 20),

                  // Features grid
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            bool oldValue = isTimeLapse;
                            bool newValue = !isTimeLapse;
                            setState(() => isTimeLapse = newValue);
                            await _updateFeatureInFirebase(
                                'timeLapse', newValue, oldValue);
                          },
                          child: _buildFeatureButton(
                            icon: Icons.timelapse,
                            label: 'Buzz on',
                            isActive: isTimeLapse,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildFeatureButton(
                          icon: Icons.track_changes,
                          label: 'Track',
                          isActive: isTracking,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildFeatureButton(
                          icon: Icons.notifications_outlined,
                          label: 'Motion dete...',
                          isActive: isMotionDetection,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildFeatureButton(
                          icon: Icons.nightlight_round,
                          label: 'Night mode',
                          isActive: isNightMode,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFeatureButton(
                          icon: Icons.settings,
                          label: 'Calibration',
                          isActive: isCalibration,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildFeatureButton(
                          icon: Icons.power_settings_new,
                          label: 'Dormancy',
                          isActive: isDormancy,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(child: Container()), // Empty space
                      SizedBox(width: 16),
                      Expanded(child: Container()), // Empty space
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 30),

            // Bottom action buttons
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Record button
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.fiber_manual_record,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  SizedBox(width: 20),

                  // Capture button
                  GestureDetector(
                    onTap: () {
                      // Add capture functionality here if needed
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),

                  Spacer(),

                  // Main control button
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.control_camera,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureButton({
    required IconData icon,
    required String label,
    required bool isActive,
    Color? color,
  }) {
    // Map button label to Firestore feature key
    String featureKey;
    switch (label) {
      case 'Buzz on':
        featureKey = 'timeLapse';
        break;
      case 'Track':
        featureKey = 'tracking';
        break;
      case 'Motion dete...':
        featureKey = 'motionDetection';
        break;
      case 'Night mode':
        featureKey = 'nightMode';
        break;
      case 'Dormancy':
        featureKey = 'dormancy';
        break;
      case 'Calibration':
        featureKey = 'calibration';
        break;
      default:
        featureKey = label;
    }

    return GestureDetector(
      onTap: () async {
        bool oldValue = isActive;
        bool newValue = !isActive;

        setState(() {
          switch (featureKey) {
            case 'timeLapse':
              isTimeLapse = newValue;
              break;
            case 'tracking':
              isTracking = newValue;
              break;
            case 'motionDetection':
              isMotionDetection = newValue;
              break;
            case 'nightMode':
              isNightMode = newValue;
              break;
            case 'dormancy':
              isDormancy = newValue;
              break;
            case 'calibration':
              isCalibration = newValue;
              break;
          }
        });

        await _updateFeatureInFirebase(featureKey, newValue, oldValue);

        // Log to Firestore when Buzz on is pressed
        if (label == 'Buzz on') {
          await FirebaseService.logFeatureChange(
            featureName: 'buzz',
            newState: newValue,
            previousState: oldValue,
            roomName: selectedRoom,
            deviceId: 'xiao_esp32s3',
          );
        }
      },
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isActive
                  ? (color ?? Colors.blue).withOpacity(0.1)
                  : Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    icon,
                    color: isActive ? (color ?? Colors.blue) : Colors.grey[600],
                    size: 24,
                  ),
                ),
                if (isLoadingFeatures)
                  Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isActive ? (color ?? Colors.blue) : Colors.grey[600]!,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
