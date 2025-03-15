import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class PointsTransactionPage extends StatefulWidget {
  @override
  _PointsTransactionPageState createState() => _PointsTransactionPageState();
}

class _PointsTransactionPageState extends State<PointsTransactionPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int totalPoints = 0;
  List<Map<String, dynamic>> transactions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserPointsAndTransactions();
  }

  Future<void> _fetchUserPointsAndTransactions() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Get current user ID
      String userId = _auth.currentUser?.uid ?? '';
      if (userId.isEmpty) {
        throw Exception('User not logged in');
      }

      // Get user points
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        setState(() {
          totalPoints = userDoc['points'] ?? 0;
        });
      }

      // Get user transactions
      QuerySnapshot transactionSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .get();

      List<Map<String, dynamic>> transactionList = [];
      for (var doc in transactionSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        transactionList.add({
          'id': doc.id,
          'points': data['points'] ?? 0,
          'type': data['type'] ?? '',
          'reason': data['reason'] ?? '',
          'timestamp': data['timestamp'],
          'item': data['item'],
          'amount': data['amount'], // For cash transactions
        });
      }

      setState(() {
        transactions = transactionList;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching points and transactions: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Get appropriate icon based on transaction type
  Widget _getTransactionIcon(String type, String reason) {
    if (type == 'deduction' && reason.toLowerCase().contains('cash')) {
      return Icon(Icons.money_off, color: Colors.black54);
    } else if (type == 'addition' && reason.toLowerCase().contains('top up')) {
      return Icon(Icons.account_balance_wallet, color: Colors.black54);
    } else if (reason.toLowerCase().contains('survey')) {
      return Icon(Icons.poll, color: Colors.black54);
    } else if (reason.toLowerCase().contains('session') ||
        reason.toLowerCase().contains('income')) {
      return Icon(Icons.attach_money, color: Colors.black54);
    } else {
      return Icon(Icons.swap_horiz, color: Colors.black54);
    }
  }

  // Format points display with + or - prefix
  String _formatPoints(int points, String type) {
    if (type == 'addition') {
      return '+$points pts';
    } else {
      return '-$points pts';
    }
  }

  // Get display text for transaction
  String _getTransactionTitle(Map<String, dynamic> transaction) {
    String reason = transaction['reason'] ?? '';

    if (reason.toLowerCase().contains('cash out')) {
      return 'Cash out';
    } else if (reason.toLowerCase().contains('top up')) {
      return 'Top up';
    } else if (reason.toLowerCase().contains('distribute survey')) {
      return 'Distribute survey';
    } else if (reason.toLowerCase().contains('do survey')) {
      return 'Do survey';
    } else if (reason.toLowerCase().contains('session')) {
      return 'Session Income';
    } else {
      return reason;
    }
  }

  // Get amount text if available
  String? _getTransactionSubtitle(Map<String, dynamic> transaction) {
    if (transaction['amount'] != null) {
      return 'RM ${transaction['amount'].toStringAsFixed(2)}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Points', style: GoogleFonts.poppins()),
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchUserPointsAndTransactions,
              child: Column(
                children: [
                  // Points summary
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 20),
                    color: Colors.orange,
                    child: Column(
                      children: [
                        Text(
                          'Total Points :',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          '$totalPoints pts',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Transactions header
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Transactions',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // Transaction list
                  Expanded(
                    child: transactions.isEmpty
                        ? Center(
                            child: Text(
                              'No transaction history',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            itemCount: transactions.length,
                            separatorBuilder: (context, index) =>
                                Divider(height: 1),
                            itemBuilder: (context, index) {
                              var transaction = transactions[index];
                              int points = transaction['points'] ?? 0;
                              String type = transaction['type'] ?? '';
                              String reason = transaction['reason'] ?? '';

                              return ListTile(
                                leading: _getTransactionIcon(type, reason),
                                title: Text(
                                  _getTransactionTitle(transaction),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle:
                                    _getTransactionSubtitle(transaction) != null
                                        ? Text(
                                            _getTransactionSubtitle(
                                                transaction)!,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          )
                                        : null,
                                trailing: Text(
                                  _formatPoints(points, type),
                                  style: GoogleFonts.poppins(
                                    color: type == 'addition'
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
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
}
