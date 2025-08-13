import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:ndef/ndef.dart';

class NFCSettingsScreen extends StatefulWidget {
  const NFCSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NFCSettingsScreen> createState() => _NFCSettingsScreenState();
}

class _NFCSettingsScreenState extends State<NFCSettingsScreen> {
  bool _nfcEnabled = true;
  bool _nfcNotifications = true;
  bool _nfcAutoPayments = false;
  late ScrollController _scrollController;
  bool _showTitle = false;
  bool _isNfcAvailable = false;
  String _nfcStatus = 'Checking NFC availability...';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    _checkNfcAvailability();
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

  Future<void> _checkNfcAvailability() async {
    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      setState(() {
        _isNfcAvailable = isAvailable;
        if (isAvailable) {
          _nfcStatus = 'NFC is available on this device';
        } else {
          _nfcStatus = 'NFC is not available on this device';
          _nfcEnabled = false;
        }
      });
    } catch (e) {
      setState(() {
        _isNfcAvailable = false;
        _nfcStatus = 'Error checking NFC: $e';
        _nfcEnabled = false;
      });
    }
  }

  Future<void> _startNfcSession() async {
    if (!_isNfcAvailable) {
      _showStatusSnackBar('NFC is not available on this device', false);
      return;
    }

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          // Handle NFC tag discovery
          _showStatusSnackBar('NFC tag detected!', true);

          // Stop the session
          await NfcManager.instance.stopSession();
        },
      );
    } catch (e) {
      _showStatusSnackBar('Error starting NFC session: $e', false);
    }
  }

  Future<void> _stopNfcSession() async {
    try {
      await NfcManager.instance.stopSession();
      _showStatusSnackBar('NFC session stopped', false);
    } catch (e) {
      _showStatusSnackBar('Error stopping NFC session: $e', false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.grey[100],
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            children: [
              SizedBox(height: 16),

              // Large NFC Settings title that disappears when scrolling
              AnimatedOpacity(
                opacity: _showTitle ? 0.0 : 1.0,
                duration: Duration(milliseconds: 200),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'NFC Settings',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),

              // Settings List
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildNFCSettingItem(
                      title: 'Enable NFC Payments',
                      subtitle: _isNfcAvailable
                          ? 'Allow payments through NFC terminal'
                          : 'NFC not available on this device',
                      value: _nfcEnabled,
                      onChanged: _isNfcAvailable
                          ? (value) {
                              setState(() {
                                _nfcEnabled = value;
                              });
                              if (value) {
                                _startNfcSession();
                              } else {
                                _stopNfcSession();
                              }
                              _showStatusSnackBar(
                                  'NFC payments ${value ? 'enabled' : 'disabled'}',
                                  value);
                            }
                          : null,
                    ),
                    Divider(height: 1, color: Colors.grey[200]),
                    _buildNFCSettingItem(
                      title: 'NFC Notifications',
                      subtitle: 'Get notified when NFC payments are made',
                      value: _nfcNotifications,
                      onChanged: (value) {
                        setState(() {
                          _nfcNotifications = value;
                        });
                        _showStatusSnackBar(
                            'NFC notifications ${value ? 'enabled' : 'disabled'}',
                            value);
                      },
                    ),
                    Divider(height: 1, color: Colors.grey[200]),
                    _buildNFCSettingItem(
                      title: 'Auto Payments',
                      subtitle:
                          'Enable automatic payments for trusted terminals',
                      value: _nfcAutoPayments,
                      onChanged: (value) {
                        setState(() {
                          _nfcAutoPayments = value;
                        });
                        _showStatusSnackBar(
                            'Auto payments ${value ? 'enabled' : 'disabled'}',
                            value);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNFCSettingItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.blue[600],
            activeTrackColor: Colors.blue[200],
          ),
        ],
      ),
    );
  }

  void _showStatusSnackBar(String message, bool isEnabled) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(),
        ),
        duration: Duration(seconds: 2),
        backgroundColor: isEnabled ? Colors.green : Colors.orange,
      ),
    );
  }
}
