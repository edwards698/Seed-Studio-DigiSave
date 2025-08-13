import 'package:digi/screens/notification_history.dart';
import 'package:flutter/material.dart';
import 'package:digi/screens/bottom_navigation.dart';
import 'package:digi/screens/setting_and_privacy.dart';
import 'package:digi/screens/security/security_screen.dart';
//Google fonts popins
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nfc_manager/nfc_manager.dart';

// Add your HomeScreen StatefulWidget here
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _transactions = [];

  void _fetchTransactions() {
    final dbRef = FirebaseDatabase.instance.ref('transactions');
    print("Setting up transactions listener...");

    dbRef.onValue.listen((event) {
      print("Received data from Firebase: ${event.snapshot.value}");
      final data = event.snapshot.value;

      if (data is Map) {
        List<Map<String, dynamic>> txList = [];
        data.forEach((key, value) {
          if (value is Map) {
            print("Processing transaction: $key -> $value");
            txList.add({
              'id': key,
              'amount': value['amount'],
              'balanceAfter': value['balanceAfter'],
              'device': value['device'],
              'timestamp': value['timestamp'],
              'type': value['type'],
            });
          }
        });

        print("Total transactions found: ${txList.length}");

        // Sort transactions by timestamp in descending order (newest first)
        txList.sort((a, b) {
          try {
            // Handle different timestamp formats
            dynamic timestampA = a['timestamp'];
            dynamic timestampB = b['timestamp'];

            DateTime dateA;
            DateTime dateB;

            // Convert timestamps to DateTime objects with better handling
            if (timestampA is String) {
              dateA = DateTime.parse(timestampA);
            } else if (timestampA is int) {
              dateA = DateTime.fromMillisecondsSinceEpoch(timestampA * 1000);
            } else {
              dateA = DateTime.fromMillisecondsSinceEpoch(
                  0); // Very old date as fallback
            }

            if (timestampB is String) {
              dateB = DateTime.parse(timestampB);
            } else if (timestampB is int) {
              dateB = DateTime.fromMillisecondsSinceEpoch(timestampB * 1000);
            } else {
              dateB = DateTime.fromMillisecondsSinceEpoch(
                  0); // Very old date as fallback
            }

            // Descending order (newest first) - newer dates have higher millisecondsSinceEpoch values
            int comparison = dateB.compareTo(dateA);

            // Add logging to verify sorting
            if (comparison != 0) {
              print(
                  "Sorting: ${a['device']} ${a['type']} (${dateA}) vs ${b['device']} ${b['type']} (${dateB}) = $comparison");
            }

            return comparison;
          } catch (e) {
            print("Error sorting transactions: $e");
            return 0; // Keep original order if parsing fails
          }
        });

        // Log the final order to verify newest is first
        if (txList.isNotEmpty) {
          print(
              "First transaction after sorting: ${txList.first['device']} ${txList.first['type']} at ${txList.first['timestamp']}");
          if (txList.length > 1) {
            print(
                "Second transaction after sorting: ${txList[1]['device']} ${txList[1]['type']} at ${txList[1]['timestamp']}");
          }
        }

        // Check for new transactions and show notifications
        final newTransactions = txList
            .where((newTx) => !_transactions
                .any((existingTx) => existingTx['id'] == newTx['id']))
            .toList();

        print("Found ${newTransactions.length} new transactions");
        print("Current _transactions count: ${_transactions.length}");

        // Show notification for each new transaction
        for (var newTx in newTransactions) {
          print(
              "Processing new transaction: ${newTx['id']} - ${newTx['type']} - \$${newTx['amount']}");
          if (_transactions.isNotEmpty) {
            // Don't show notifications on initial load
            print(
                "Showing notification for: ${newTx['type']} - \$${newTx['amount']} from ${newTx['device']}");

            // Show notification for ALL new transactions (mobile app AND terminal)
            String deviceName =
                newTx['device'] == 'Mobile App' ? 'Mobile App' : 'Terminal';
            _showNotification(
              '${newTx['type'] == 'deposit' ? 'Deposit' : 'Withdrawal'} from $deviceName',
              'Device: ${newTx['device']} | Amount: \$${newTx['amount']}',
            );
          } else {
            print("Skipping notification on initial load");
          }
        }

        setState(() {
          _transactions = txList;
        });
        print("Transactions updated in UI: ${_transactions.length}");
      } else {
        print("No transaction data found or data is not a Map: $data");
        setState(() {
          _transactions = [];
        });
      }
    }).onError((error) {
      print("Error fetching transactions: $error");
    });
  }

  int _selectedIndex = 0; // Index for the selected bottom navigation item
  String? selectedPocket;

  // Balance fetched from Realtime Database
  double _fetchedBalance = 441.00; // Default balance

  // NFC-related state variables
  bool _isNfcAvailable = false;

// Removed duplicate/stray Expanded widget and transaction list code that was outside the main widget tree.
// Removed stray code block that was outside any function or widget.
// ...existing code...

  final List<String> pockets = ['Rentals', 'Holiday', 'Expense'];
  final Map<String, double> pocketBalances = {
    'Rentals': 1200.00,
    'Holiday': 600.50,
    'Expense': 441.00,
  };

  // Return balance fetched from Firestore
  double get selectedPocketBalance {
    return _fetchedBalance;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
    _fetchBalanceFromRealtimeDB();
    _initializeNFC();
    AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });
  }

  @override
  void dispose() {
    // Stop NFC session if it's running (both manual and automatic)
    try {
      NfcManager.instance.stopSession();
    } catch (e) {
      print("Error stopping NFC session in dispose: $e");
    }
    super.dispose();
  }

  // Fetch balance from Realtime Database
  void _fetchBalanceFromRealtimeDB() {
    final dbRef = FirebaseDatabase.instance.ref('account/balance');
    dbRef.onValue.listen((event) {
      final balance = event.snapshot.value;
      if (balance != null) {
        final parsedBalance = double.tryParse(balance.toString()) ?? 441.00;
        if (_fetchedBalance != parsedBalance) {
          String changeType =
              parsedBalance > _fetchedBalance ? 'Deposit' : 'Withdrawal';
          double changeAmount = (parsedBalance - _fetchedBalance).abs();
          _showNotification(
            '$changeType Bank Terminal',
            'Amount: \$${changeAmount.toStringAsFixed(2)}',
          );
        }
        setState(() {
          _fetchedBalance = parsedBalance;
        });
        print("Fetched balance from RTDB: $parsedBalance");
      } else {
        print("No balance found in RTDB");
      }
    });
  }

  void _showNotification(String title, String body) {
    print("_showNotification called with title: '$title', body: '$body'");
    AwesomeNotifications()
        .createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: 'basic_channel',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
      ),
    )
        .then((_) {
      print("Notification created successfully");
    }).catchError((error) {
      print("Error creating notification: $error");
    });
  }

  // Initialize NFC functionality
  void _initializeNFC() async {
    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      setState(() {
        _isNfcAvailable = isAvailable;
      });

      if (isAvailable) {
        print("NFC is available on this device");
        // Start automatic NFC scanning when app loads
        _startAutomaticNFCScanning();
      } else {
        print("NFC is not available on this device");
      }
    } catch (e) {
      print("Error initializing NFC: $e");
      setState(() {
        _isNfcAvailable = false;
      });
    }
  }

  // Start NFC scanning for RC522 cards (for manual use in sheets)
  void _startNFCScanning({
    Function(bool, double)? onPaymentSuccess,
    Function(String, String?, bool)? onStatusUpdate,
  }) async {
    if (!_isNfcAvailable) {
      _showNotification('NFC Error', 'NFC is not available on this device');
      return;
    }

    // Update status using callback
    if (onStatusUpdate != null) {
      onStatusUpdate('Scanning for RC522 card...', null, true);
    }

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          print("NFC tag detected: ${tag.data}");

          // Extract card UID for RC522 cards
          String? cardId = _extractCardId(tag);

          // Update status using callback
          if (onStatusUpdate != null) {
            onStatusUpdate(
              cardId != null
                  ? 'RC522 Card Detected: $cardId'
                  : 'Card detected but not RC522 compatible',
              cardId,
              false,
            );
          }

          if (cardId != null) {
            _showNotification('RC522 Card Detected', 'Card ID: $cardId');
            // Process payment automatically when RC522 card is detected
            double paymentAmount = await _processNFCPayment(cardId);

            // Call the success callback if provided
            if (onPaymentSuccess != null && paymentAmount > 0) {
              onPaymentSuccess(true, paymentAmount);
            }
          }

          // Stop NFC session after detection
          await NfcManager.instance.stopSession();
        },
      );
    } catch (e) {
      print("Error during NFC scanning: $e");
      if (onStatusUpdate != null) {
        onStatusUpdate('Error scanning for NFC cards', null, false);
      }
      _showNotification('NFC Error', 'Failed to scan for NFC cards');
      await NfcManager.instance.stopSession();
    }
  }

  // Extract card ID from NFC tag data
  String? _extractCardId(NfcTag tag) {
    try {
      // Try to get UID from different NFC technologies

      // NfcA (most common for RC522)
      if (tag.data['nfca'] != null) {
        final nfcA = tag.data['nfca'];
        if (nfcA['identifier'] != null) {
          List<int> uid = List<int>.from(nfcA['identifier']);
          return uid
              .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
              .join(':')
              .toUpperCase();
        }
      }

      // NfcB
      if (tag.data['nfcb'] != null) {
        final nfcB = tag.data['nfcb'];
        if (nfcB['identifier'] != null) {
          List<int> uid = List<int>.from(nfcB['identifier']);
          return uid
              .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
              .join(':')
              .toUpperCase();
        }
      }

      // NfcF
      if (tag.data['nfcf'] != null) {
        final nfcF = tag.data['nfcf'];
        if (nfcF['identifier'] != null) {
          List<int> uid = List<int>.from(nfcF['identifier']);
          return uid
              .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
              .join(':')
              .toUpperCase();
        }
      }

      // NfcV
      if (tag.data['nfcv'] != null) {
        final nfcV = tag.data['nfcv'];
        if (nfcV['identifier'] != null) {
          List<int> uid = List<int>.from(nfcV['identifier']);
          return uid
              .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
              .join(':')
              .toUpperCase();
        }
      }

      print("Could not extract card ID from tag data: ${tag.data}");
      return null;
    } catch (e) {
      print("Error extracting card ID: $e");
      return null;
    }
  }

  // Process NFC payment when RC522 card is detected
  Future<double> _processNFCPayment(String cardId) async {
    double paymentAmount = 25.0; // Default payment amount

    if (_fetchedBalance >= paymentAmount) {
      setState(() {
        _fetchedBalance -= paymentAmount;
      });

      // Add transaction to Firebase
      _addTransactionToFirebase('withdrawal', paymentAmount);

      _showNotification('NFC Payment Successful',
          'RC522 Card: $cardId\nAmount: \$${paymentAmount.toStringAsFixed(2)}');

      return paymentAmount;
    } else {
      _showNotification('Payment Failed', 'Insufficient balance for payment');
      return 0.0;
    }
  }

  // Stop NFC scanning
  void _stopNFCScanning(
      {Function(String, String?, bool)? onStatusUpdate}) async {
    try {
      await NfcManager.instance.stopSession();
      if (onStatusUpdate != null) {
        onStatusUpdate('NFC scanning stopped', null, false);
      }
    } catch (e) {
      print("Error stopping NFC session: $e");
    }
  }

  // Start automatic NFC scanning in background
  void _startAutomaticNFCScanning() async {
    if (!_isNfcAvailable) {
      return;
    }

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          print("NFC tag detected automatically: ${tag.data}");

          // Extract card UID for RC522 cards
          String? cardId = _extractCardId(tag);

          if (cardId != null) {
            _showNotification('RC522 Card Detected', 'Card ID: $cardId');

            // Stop current session before showing PIN sheet
            await NfcManager.instance.stopSession();

            // Show PIN entry draggable sheet
            _showPINEntrySheet(cardId);
          }
        },
      );
    } catch (e) {
      print("Error during automatic NFC scanning: $e");
    }
  }

  // Show PIN entry draggable sheet when card is detected
  void _showPINEntrySheet(String cardId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.9,
        maxChildSize: 1.0,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10.0,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: _buildPINEntryContent(cardId),
        ),
      ),
    ).then((_) {
      // Restart automatic NFC scanning when sheet is closed
      Future.delayed(Duration(milliseconds: 500), () {
        _startAutomaticNFCScanning();
      });
    });
  }

  // Build PIN entry content
  Widget _buildPINEntryContent(String cardId) {
    TextEditingController pinController = TextEditingController();
    bool isProcessing = false;
    String? pinError;
    final String correctPin =
        "1234"; // You can change this or make it configurable

    return StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar for dragging
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Row(
              children: [
                Image.asset(
                  'assets/icons/nfc.png',
                  width: 30,
                  height: 30,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'RC522 Card Payment',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.grey[600]),
                ),
              ],
            ),

            Divider(),
            SizedBox(height: 20),

            // PIN entry section
            Text(
              'Enter PIN to Complete Payment',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 20),

            // PIN display field (read-only)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: pinError != null ? Colors.red[50] : Colors.grey[50],
                border: pinError != null
                    ? Border.all(color: Colors.red[300]!, width: 1.5)
                    : null,
              ),
              child: Text(
                pinController.text.isEmpty
                    ? '• • • •'
                    : pinController.text.split('').map((char) => '•').join(' '),
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: pinError != null
                      ? Colors.red[600]
                      : pinController.text.isEmpty
                          ? Colors.grey[400]
                          : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            SizedBox(height: 20),

            // Custom Number Pad
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Numbers 1-3
                  Row(
                    children: [
                      Expanded(
                          child: _buildNumberButton('1', pinController,
                              setSheetState, pinError, () => pinError = null)),
                      SizedBox(width: 12),
                      Expanded(
                          child: _buildNumberButton('2', pinController,
                              setSheetState, pinError, () => pinError = null)),
                      SizedBox(width: 12),
                      Expanded(
                          child: _buildNumberButton('3', pinController,
                              setSheetState, pinError, () => pinError = null)),
                    ],
                  ),
                  SizedBox(height: 12),
                  // Numbers 4-6
                  Row(
                    children: [
                      Expanded(
                          child: _buildNumberButton('4', pinController,
                              setSheetState, pinError, () => pinError = null)),
                      SizedBox(width: 12),
                      Expanded(
                          child: _buildNumberButton('5', pinController,
                              setSheetState, pinError, () => pinError = null)),
                      SizedBox(width: 12),
                      Expanded(
                          child: _buildNumberButton('6', pinController,
                              setSheetState, pinError, () => pinError = null)),
                    ],
                  ),
                  SizedBox(height: 12),
                  // Numbers 7-9
                  Row(
                    children: [
                      Expanded(
                          child: _buildNumberButton('7', pinController,
                              setSheetState, pinError, () => pinError = null)),
                      SizedBox(width: 12),
                      Expanded(
                          child: _buildNumberButton('8', pinController,
                              setSheetState, pinError, () => pinError = null)),
                      SizedBox(width: 12),
                      Expanded(
                          child: _buildNumberButton('9', pinController,
                              setSheetState, pinError, () => pinError = null)),
                    ],
                  ),
                  SizedBox(height: 12),
                  // 0 and Clear button row
                  Row(
                    children: [
                      Expanded(child: Container()), // Empty space (column 1)
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildNumberButton('0', pinController,
                            setSheetState, pinError, () => pinError = null),
                      ), // Column 2 (under 2, 5, 8)
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildClearButton(pinController, setSheetState,
                            () => pinError = null),
                      ), // Column 3 (under 3, 6, 9)
                    ],
                  ),
                ],
              ),
            ),

            // PIN error message
            if (pinError != null) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[600], size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pinError!,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 30),

            // Payment amount display
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Payment Amount:',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: const Color.fromARGB(255, 0, 0, 0),
                    ),
                  ),
                  Text(
                    '\$25.00',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 0, 0, 0),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Additional Action Buttons

            // Main Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        isProcessing ? null : () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.close, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isProcessing
                        ? null
                        : () async {
                            String enteredPin = pinController.text.trim();

                            // Validate PIN length
                            if (enteredPin.length != 4) {
                              setSheetState(() {
                                pinError = 'PIN must be 4 digits';
                              });
                              return;
                            }

                            // Check if PIN is correct
                            if (enteredPin != correctPin) {
                              setSheetState(() {
                                pinError = 'Incorrect PIN. Please try again.';
                              });

                              // Clear the PIN field for retry
                              pinController.clear();
                              return;
                            }

                            // PIN is correct, start processing
                            setSheetState(() {
                              isProcessing = true;
                              pinError = null;
                            });

                            try {
                              // Simulate processing delay
                              await Future.delayed(Duration(seconds: 2));

                              // Process the payment automatically
                              double paymentAmount =
                                  await _processNFCPayment(cardId);

                              if (paymentAmount > 0) {
                                // Close PIN sheet
                                Navigator.pop(context);
                              } else {
                                // Payment failed (insufficient balance)
                                setSheetState(() {
                                  isProcessing = false;
                                  pinError =
                                      'Payment failed: Insufficient balance';
                                });
                              }
                            } catch (e) {
                              // Handle any errors during payment processing
                              setSheetState(() {
                                isProcessing = false;
                                pinError =
                                    'Payment processing failed. Please try again.';
                              });
                              print("Error processing payment: $e");
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isProcessing ? Colors.grey[400] : Colors.black,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isProcessing
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Processing...',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.payment, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Pay \$25.00',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Helper method to build number buttons for PIN pad
  Widget _buildNumberButton(String number, TextEditingController pinController,
      Function setSheetState, String? pinError, Function() clearError) {
    return GestureDetector(
      onTap: () {
        if (pinController.text.length < 4) {
          pinController.text += number;
          setSheetState(() {
            // Clear error when user starts typing
            clearError();
          });
        }
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            number,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build clear button for PIN pad
  Widget _buildClearButton(TextEditingController pinController,
      Function setSheetState, Function() clearError) {
    return GestureDetector(
      onTap: () {
        setSheetState(() {
          if (pinController.text.isNotEmpty) {
            pinController.text =
                pinController.text.substring(0, pinController.text.length - 1);
          } else {
            // If PIN is empty, clear all to start fresh
            pinController.clear();
          }
          // Clear error when user uses clear button
          clearError();
        });
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.red[50],
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.backspace_outlined,
            color: Colors.red[600],
            size: 24,
          ),
        ),
      ),
    );
  }

  // Helper method to build quick amount selection buttons
  Widget _buildQuickAmountButton(
      String label, double amount, Function setSheetState) {
    return GestureDetector(
      onTap: () {
        setSheetState(() {
          // You can use this to update a selected amount variable if needed
          // For now, it just provides visual feedback
        });
        _showNotification('Amount Selected', '$label selected for payment');
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.blue[700],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // Helper method to build payment type buttons
  Widget _buildPaymentTypeButton(String label, IconData icon, Color color,
      VoidCallback onTap, bool isProcessing) {
    return GestureDetector(
      onTap: isProcessing ? null : onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isProcessing ? Colors.grey[100] : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isProcessing ? Colors.grey[300]! : color.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isProcessing ? Colors.grey[400] : color,
              size: 24,
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isProcessing ? Colors.grey[400] : color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build action buttons
  Widget _buildActionButton(String label, IconData icon, Color color,
      VoidCallback onTap, bool isProcessing) {
    return GestureDetector(
      onTap: isProcessing ? null : onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isProcessing ? Colors.grey[100] : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isProcessing ? Colors.grey[300]! : color.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isProcessing ? Colors.grey[400] : color,
              size: 18,
            ),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isProcessing ? Colors.grey[400] : color,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Handle Express Pay functionality
  void _handleExpressPay(String cardId, TextEditingController pinController,
      Function setSheetState, bool isProcessing) async {
    if (isProcessing) return;

    // Check if PIN is entered
    if (pinController.text.trim().isEmpty) {
      setSheetState(() {
        // Show error that PIN is required
      });
      _showNotification('Express Pay', 'Please enter your PIN first');
      return;
    }

    // Express pay with minimal validation
    _showNotification('Express Pay', 'Processing express payment...');

    // Simulate quick processing
    await Future.delayed(Duration(milliseconds: 500));

    double paymentAmount = await _processNFCPayment(cardId);
    if (paymentAmount > 0) {
      Navigator.pop(context);
    }
  }

  // Handle Secure Pay functionality
  void _handleSecurePay(String cardId, TextEditingController pinController,
      Function setSheetState, bool isProcessing) async {
    if (isProcessing) return;

    // More secure validation
    String enteredPin = pinController.text.trim();
    final String correctPin = "1234";

    if (enteredPin.length != 4) {
      _showNotification('Secure Pay', 'PIN must be 4 digits');
      return;
    }

    if (enteredPin != correctPin) {
      _showNotification('Secure Pay', 'Invalid PIN for secure payment');
      pinController.clear();
      return;
    }

    _showNotification('Secure Pay',
        'Processing secure payment with additional verification...');

    // Simulate secure processing with longer delay
    await Future.delayed(Duration(seconds: 1));

    double paymentAmount = await _processNFCPayment(cardId);
    if (paymentAmount > 0) {
      Navigator.pop(context);
    }
  }

  // Show balance information
  void _showBalanceInfo(Function setSheetState) {
    _showNotification('Account Balance',
        'Current balance: \$${_fetchedBalance.toStringAsFixed(2)}');
  }

  // Show transaction history (simplified version)
  void _showTransactionHistory() {
    // Navigate to notifications tab to show transaction history
    setState(() {
      _selectedIndex = 1;
    });
    Navigator.pop(context);
    _showNotification('Transaction History', 'Viewing recent transactions');
  }

  void _deposit(double amount) {
    setState(() {
      _fetchedBalance += amount;
    });
    _showNotification(
        'Deposit Successful', 'You deposited \$${amount.toStringAsFixed(2)}');

    // Add transaction to Firebase
    _addTransactionToFirebase('deposit', amount);
  }

  void _withdraw(double amount) {
    if (_fetchedBalance >= amount) {
      setState(() {
        _fetchedBalance -= amount;
      });
      _showNotification('Withdrawal Successful',
          'You withdrew \$${amount.toStringAsFixed(2)}');

      // Add transaction to Firebase
      _addTransactionToFirebase('withdrawal', amount);
    } else {
      _showNotification(
          'Withdrawal Failed', 'Insufficient balance for withdrawal.');
    }
  }

  // Add transaction to Firebase Realtime Database
  void _addTransactionToFirebase(String type, double amount) {
    final dbRef = FirebaseDatabase.instance.ref('transactions');
    final timestamp = DateTime.now().toIso8601String();

    dbRef.push().set({
      'amount': amount,
      'balanceAfter': _fetchedBalance,
      'device': 'Mobile App',
      'timestamp': timestamp,
      'type': type,
    }).then((_) {
      print(
          "Transaction added successfully: $type, \$${amount.toStringAsFixed(2)}");
    }).catchError((error) {
      print("Error adding transaction: $error");
    });
  }

  // Show NFC payment bottom sheet
  void _showNFCPaymentSheet() {
    bool isPaymentSuccessful = false;
    double transactionAmount = 0.0;

    // Local state for the sheet to avoid setState conflicts
    bool localIsNfcReading = false;
    String localNfcStatus = 'Ready to scan';
    String? localDetectedCardId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10.0,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar (optional - can be removed since it's now static)
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/icons/seed.png',
                      width: 30,
                      height: 30,
                    ),
                    SizedBox(width: 12),
                    Text(
                      isPaymentSuccessful
                          ? 'Payment Successful!'
                          : 'NFC Payment Wio Terminal',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isPaymentSuccessful
                            ? Colors.green[700]
                            : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: !isPaymentSuccessful
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // NFC Status indicator
                            Container(
                              padding: EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  // Lottie animation for NFC
                                  Container(
                                    width: 220,
                                    height: 220,
                                    child: Lottie.asset(
                                      'assets/animations/nfc.json',
                                      fit: BoxFit.contain,
                                      repeat: localIsNfcReading,
                                      animate: localIsNfcReading,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    localIsNfcReading
                                        ? 'Scanning for RC522...'
                                        : 'Ready for RC522 Payment',
                                    style: GoogleFonts.poppins(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: localIsNfcReading
                                          ? const Color.fromARGB(
                                              255, 99, 153, 247)
                                          : const Color.fromARGB(255, 0, 0, 0),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    localNfcStatus,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (localDetectedCardId != null) ...[
                                    SizedBox(height: 12),
                                    Container(
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.green[200]!),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(Icons.credit_card,
                                              color: Colors.green[600],
                                              size: 32),
                                          SizedBox(height: 8),
                                          Text(
                                            'RC522 Card Detected',
                                            style: GoogleFonts.poppins(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green[700],
                                            ),
                                          ),
                                          Text(
                                            'ID: $localDetectedCardId',
                                            style: GoogleFonts.robotoMono(
                                              fontSize: 12,
                                              color: Colors.green[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            SizedBox(height: 32),

                            // NFC Scan button
                            if (!localIsNfcReading &&
                                localDetectedCardId == null)
                              ElevatedButton(
                                onPressed: _isNfcAvailable
                                    ? () {
                                        _startNFCScanning(
                                          onPaymentSuccess: (success, amount) {
                                            if (success) {
                                              setSheetState(() {
                                                isPaymentSuccessful = true;
                                                transactionAmount = amount;
                                              });
                                            }
                                          },
                                          onStatusUpdate:
                                              (status, cardId, isReading) {
                                            setSheetState(() {
                                              localNfcStatus = status;
                                              localDetectedCardId = cardId;
                                              localIsNfcReading = isReading;
                                            });
                                          },
                                        );
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isNfcAvailable
                                      ? const Color.fromARGB(255, 0, 0, 0)
                                      : Colors.grey[400],
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.nfc, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      _isNfcAvailable
                                          ? 'Scan RC522 Card'
                                          : 'NFC Not Available',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Stop scanning button
                            if (localIsNfcReading)
                              ElevatedButton(
                                onPressed: () {
                                  _stopNFCScanning(
                                    onStatusUpdate:
                                        (status, cardId, isReading) {
                                      setSheetState(() {
                                        localNfcStatus = status;
                                        localDetectedCardId = cardId;
                                        localIsNfcReading = isReading;
                                      });
                                    },
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[600],
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.stop, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Stop Scanning',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            SizedBox(height: 16),
                            // Close button
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[300]!,
                                foregroundColor: Colors.grey[600],
                                padding: EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Close',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          // Success view
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: 40),
                            // Success animation
                            Container(
                              width: 150,
                              height: 150,
                              child: Lottie.asset(
                                'assets/animations/success_tick.json',
                                fit: BoxFit.contain,
                                repeat: false,
                                animate: true,
                              ),
                            ),
                            SizedBox(height: 30),
                            // Transaction details
                            Text(
                              'Payment of \$${transactionAmount.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'has been processed successfully',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 30),
                            // Balance info
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'New Balance:',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  Text(
                                    '\$${_fetchedBalance.toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 40),
                            // Done button
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[600],
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Done',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Open Seeed Studio GitHub page in app browser
  void _openSeedStudioGitHub() {
    print("Opening GitHub in draggable sheet");
    // Directly open the draggable scroll sheet
    _showGitHubSheet();
  }

  // Open DigiSave GitHub page in app browser
  void _openDigiSaveGitHub() {
    print("Opening DigiSave GitHub in draggable sheet");
    // Directly open the draggable scroll sheet
    _showDigiSaveGitHubSheet();
  }

  // Show GitHub in draggable scrollable sheet
  void _showGitHubSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.3,
        minChildSize: 0.2,
        maxChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10.0,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar for dragging
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header with title and close button
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/icons/seed.png',
                      width: 30,
                      height: 30,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Seeed Studio GitHub',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
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

              Divider(height: 1, color: Colors.grey[300]),

              // URL address bar
              Container(
                padding: EdgeInsets.all(16),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/icons/github.png',
                        width: 16,
                        height: 16,
                        color: const Color.fromARGB(255, 0, 0, 0),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'GitHub',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          // Open in external browser
                          final Uri uri =
                              Uri.parse('https://github.com/seeed-studio');
                          try {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          } catch (e) {
                            print('Error opening external browser: $e');
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.open_in_new,
                              color: Colors.blue, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Add some bottom padding to prevent content from being too close to the edge
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // Show DigiSave GitHub in draggable scrollable sheet
  void _showDigiSaveGitHubSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.3,
        minChildSize: 0.2,
        maxChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10.0,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar for dragging
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header with title and close button
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/icons/terminal.png',
                      width: 30,
                      height: 30,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'My GitHub Repository',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
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

              Divider(height: 1, color: Colors.grey[300]),

              // URL address bar
              Container(
                padding: EdgeInsets.all(16),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/icons/github.png',
                        width: 16,
                        height: 16,
                        color: const Color.fromARGB(255, 0, 0, 0),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'DigiSave Repository',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          // Open in external browser
                          final Uri uri = Uri.parse(
                              'https://github.com/edwards698/Seed-Studio-DigiSave');
                          try {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          } catch (e) {
                            print('Error opening external browser: $e');
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.open_in_new,
                              color: Colors.blue, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Add some bottom padding to prevent content from being too close to the edge
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show NotificationHistoryScreen if Notifications tab is selected
    if (_selectedIndex == 1) {
      // Convert _transactions to List<Map<String, String>> for NotificationHistoryScreen
      // Transactions are already sorted by timestamp (newest first) from _fetchTransactions()
      final notifications = _transactions
          .map((tx) => {
                'title':
                    '${tx['type'] == 'deposit' ? 'Deposit' : 'Withdrawal'} from ${tx['device'] == 'Mobile App' ? 'Mobile App' : 'Terminal'}',
                'body':
                    'Device: ${tx['device']} | Time: ${tx['timestamp']} | Amount: \$${tx['amount']}',
                'device': tx['device'].toString(), // Add device field
                'type': tx['type'].toString(), // Add type field
                'amount': tx['amount'].toString(), // Add amount field
                'timestamp':
                    tx['timestamp'].toString(), // Add timestamp for sorting
              })
          .toList();

      // Extra sort to ensure newest transactions are always on top
      notifications.sort((a, b) {
        try {
          dynamic timestampA = a['timestamp'];
          dynamic timestampB = b['timestamp'];

          DateTime dateA;
          DateTime dateB;

          // Handle string timestamps (ISO format)
          if (timestampA is String) {
            dateA = DateTime.parse(timestampA);
          } else {
            dateA = DateTime.fromMillisecondsSinceEpoch(
                0); // Very old date as fallback
          }

          if (timestampB is String) {
            dateB = DateTime.parse(timestampB);
          } else {
            dateB = DateTime.fromMillisecondsSinceEpoch(
                0); // Very old date as fallback
          }

          // Descending order (newest first)
          int comparison = dateB.compareTo(dateA);

          // Add logging for notification sorting
          print(
              "Notification sorting: ${a['device']} vs ${b['device']} = $comparison");

          return comparison;
        } catch (e) {
          print("Error sorting notifications: $e");
          return 0;
        }
      });

      // Log final notification order
      if (notifications.isNotEmpty) {
        print(
            "First notification: ${notifications.first['device']} ${notifications.first['type']} at ${notifications.first['timestamp']}");
      }
      return Scaffold(
        backgroundColor: Colors.grey[200],
        body: NotificationHistoryScreen(notifications: notifications),
        bottomNavigationBar: CustomBottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
        ),
      );
    }

    // Show TerminalLibraryScreen if Settings tab is selected
    if (_selectedIndex == 2) {
      return Scaffold(
        backgroundColor: Colors.grey[200],
        body: TerminalLibraryScreen(),
        bottomNavigationBar: CustomBottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
        ),
      );
    }

    // Default: Show main home screen (Pockets tab)
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                          width:
                              8), // Space between the name and profile picture

                      // Profile Picture
                      const CircleAvatar(
                        backgroundImage: AssetImage(
                            'assets/images/Mr._Krabs.png'), // Path to local asset
                        radius: 20,
                      ),
                      const SizedBox(width: 10),
                      // User Name Text
                      Text(
                        'Edward Phiri', // Replace with the user's name or a variable
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),

                  // Image.asset(
                  //   'assets/icons/setting.png', // Path to local asset
                  //   width: 24,
                  //   height: 24,
                  // ),
                ],
              ),
              const SizedBox(height: 24),
              RepaintBoundary(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      // BoxShadow settings
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExpansionTile(
                        title: Text(
                          selectedPocket ?? 'Main Pocket',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            color: Color.fromARGB(255, 70, 130, 180),
                            //fontWeight: FontWeight.bold,
                          ),
                        ),
                        children: pockets.map((pocket) {
                          return ListTile(
                            title: Text(
                              "$pocket - \$${selectedPocketBalance.toStringAsFixed(2)}",
                            ),
                            onTap: () {
                              setState(() {
                                selectedPocket = pocket;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '\$${selectedPocketBalance.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '*6749',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          Row(
                            children: [
                              Image.asset(
                                'assets/icons/visa.png', // Path to local asset
                                width: 32,
                                height: 32,
                              ),
                              const SizedBox(width: 8),
                              Image.asset(
                                'assets/icons/master.png', // Path to local asset
                                width: 32,
                                height: 32,
                              ),
                              const SizedBox(width: 8),
                              Image.asset(
                                'assets/icons/seed.png', // Path to local asset
                                width: 32,
                                height: 32,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => _deposit(50.0), // Example deposit
                    style: ElevatedButton.styleFrom(
                      shape: const StadiumBorder(),
                      backgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 12),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/icons/get_money.png', // Path to your asset icon
                          width: 25, // Adjust size as needed
                          height: 25,
                        ),
                        const SizedBox(width: 8), // Space between icon and text
                        Text(
                          "Get",
                          style: GoogleFonts.poppins(color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _withdraw(20.0), // Example withdraw
                    style: ElevatedButton.styleFrom(
                      shape: const StadiumBorder(),
                      backgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 12),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/icons/Send_money.png', // Path to your asset icon
                          width: 25, // Adjust size as needed
                          height: 25,
                        ),
                        const SizedBox(width: 8), // Space between icon and text
                        Text(
                          "Send",
                          style: GoogleFonts.poppins(color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _showNFCPaymentSheet,
                    style: ElevatedButton.styleFrom(
                      shape: const StadiumBorder(),
                      backgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 12),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/icons/nfc.png',
                          width: 25, // Adjust icon size as needed
                          height: 25,
                        ),
                        const SizedBox(width: 8), // Space between icon and text
                        Text(
                          "Deposit",
                          style: GoogleFonts.poppins(color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Library Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Library",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigate to full library screen
                    },
                    child: Text(
                      "View All",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Library Cards Grid
              Row(
                children: [
                  // Security App Card - Large
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: () {
                        // Navigate to Security Screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SecurityScreen(),
                          ),
                        );
                      },
                      child: Container(
                        height: 120,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[200],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Image.asset(
                                  'assets/icons/video.png',
                                  width: 24,
                                  height: 24,
                                  color: Colors.orange[800],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "New",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              "Security App",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              "32 Items",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Gym UI Library Card - Small
                  Expanded(
                    flex: 1,
                    child: GestureDetector(
                      onTap: () {
                        // Open DigiSave GitHub page in app browser
                        _openDigiSaveGitHub();
                      },
                      child: Container(
                        height: 120,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Image.asset(
                                  'assets/icons/terminal.png',
                                  width: 20,
                                  height: 20,
                                  color: Colors.grey[700],
                                ),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.yellow,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              "My Library",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              "1 Items",
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Second Row of Library Cards
              Row(
                children: [
                  // Education Card - Small
                  Expanded(
                    flex: 1,
                    child: GestureDetector(
                      onTap: () {
                        // Open Seeed Studio GitHub page in app browser
                        _openSeedStudioGitHub();
                      },
                      child: Container(
                        height: 100,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Image.asset(
                                  'assets/icons/seed.png',
                                  width: 20,
                                  height: 20,
                                  color: Colors.grey[700],
                                ),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.yellow,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              "Seed Studio\nOpen Source",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Task Manager Card - Small
                  Expanded(
                    flex: 1,
                    child: GestureDetector(
                      onTap: () {
                        // // Navigate to Terminal Library Screen
                        // Navigator.push(
                        //   context,
                        //   MaterialPageRoute(
                        //     builder: (context) => TerminalLibraryScreen(),
                        //   ),
                        // );
                      },
                      child: Container(
                        height: 100,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(
                                  Icons.add_circle_outline,
                                  color: Colors.grey[700],
                                  size: 20,
                                ),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.yellow,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              "Add Task",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}

class TransactionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String amount;
  final Color iconColor;
  final String device; // Add device parameter

  const TransactionItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.iconColor,
    required this.device, // Make device required
  });

  @override
  Widget build(BuildContext context) {
    // Determine which icon to show based on device
    String deviceIcon;
    if (device == 'Mobile App') {
      deviceIcon = 'assets/icons/smartphone.png'; // Mobile phone icon
    } else {
      deviceIcon =
          'assets/icons/terminal.png'; // Terminal icon for terminal transactions
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.grey[100], // Light background
                radius: 20, // Adjust radius as needed
                child: Image.asset(
                  deviceIcon, // Use device-specific icon
                  width: 24, // Adjust width as needed
                  height: 24, // Adjust height as needed
                  fit: BoxFit.contain, // Make sure icon shows fully
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          Text(
            amount,
            style: GoogleFonts.poppins(
                fontSize: 16, color: const Color.fromARGB(255, 33, 150, 243)),
          ),
        ],
      ),
    );
  }
}
