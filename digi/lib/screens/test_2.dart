import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: GoogleFonts.poppinsTextTheme(), // Custom font
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String? selectedPocket;
  Map<String, double> pocketBalances = {}; // Stores pockets and their balances

  @override
  void initState() {
    super.initState();
    _fetchPocketsFromFirestore();
  }

  // Fetch pockets and balances from Firestore
  Future<void> _fetchPocketsFromFirestore() async {
    FirebaseFirestore.instance
        .collection('pockets')
        .snapshots()
        .listen((snapshot) {
      Map<String, double> newPocketBalances = {};
      for (var doc in snapshot.docs) {
        String pocketName = doc.id; // Use document ID as the pocket name
        double balance =
            doc.data()['balance']?.toDouble() ?? 0.0; // Retrieve balance

        newPocketBalances[pocketName] = balance;
      }
      setState(() {
        pocketBalances = newPocketBalances;
      });
    });
  }

  double get selectedPocketBalance {
    return pocketBalances[selectedPocket] ?? 0.0;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                      const CircleAvatar(
                        backgroundImage:
                            AssetImage('assets/images/Mr._Krabs.png'),
                        radius: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Edward Phiri',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  Image.asset(
                    'assets/icons/setting.png',
                    width: 24,
                    height: 24,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              RepaintBoundary(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExpansionTile(
                        title: Text(
                          selectedPocket ?? 'Main Pocket',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            color: const Color.fromARGB(255, 70, 130, 180),
                          ),
                        ),
                        children: pocketBalances.keys.map((pocket) {
                          return ListTile(
                            title: Text(
                              "$pocket - \$${pocketBalances[pocket]!.toStringAsFixed(2)}",
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
                                'assets/icons/visa.png',
                                width: 32,
                                height: 32,
                              ),
                              const SizedBox(width: 8),
                              Image.asset(
                                'assets/icons/master.png',
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
            ],
          ),
        ),
      ),
    );
  }
}
