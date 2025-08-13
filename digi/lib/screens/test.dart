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
        textTheme: GoogleFonts.poppinsTextTheme(),
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
  double _fetchedBalance = 441.00;

  @override
  void initState() {
    super.initState();
    _fetchBalanceFromFirestore();
  }

  Future<void> _fetchBalanceFromFirestore() async {
    FirebaseFirestore.instance
        .collection('pockets')
        .doc('main-pocket')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final message = snapshot.get('message') as String;
        final balanceString = message.split(': ')[1];
        final balance = double.tryParse(balanceString) ?? 441.00;

        setState(() {
          _fetchedBalance = balance;
        });
      } else {
        print("Document does not exist in Firestore");
      }
    });
  }

  Future<void> _addTransaction(double amount) async {
    final transaction = {
      'amount': amount,
      'date': DateTime.now(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('pockets')
          .doc('main-pocket')
          .collection('transactions')
          .add(transaction);

      print("Transaction added successfully!");
    } catch (e) {
      print("Error adding transaction: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Pocket Balance: ${_fetchedBalance.toStringAsFixed(2)}"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Pocket Balance: ${_fetchedBalance.toStringAsFixed(2)}",
              style: TextStyle(fontSize: 24),
            ),
            ElevatedButton(
              onPressed: () async {
                double transactionAmount = 50.00;
                await _addTransaction(transactionAmount);
                print(
                    "Transaction of \$${transactionAmount.toStringAsFixed(2)} added.");
              },
              child: Text("Add Transaction"),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('pockets')
                    .doc('main-pocket')
                    .collection('transactions')
                    .orderBy('date', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text("Error: ${snapshot.error}");
                  }
                  if (!snapshot.hasData) {
                    return CircularProgressIndicator();
                  }
                  if (snapshot.data!.docs.isEmpty) {
                    return Text("No transactions available.");
                  }
                  final transactions = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final transaction = transactions[index];
                      final amount = transaction.get('amount');
                      final date = transaction.get('date').toDate();
                      return ListTile(
                        title: Text("Amount: \$${amount.toStringAsFixed(2)}"),
                        subtitle: Text("Date: ${date.toLocal()}"),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
