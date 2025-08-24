import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../widgets/fancy_navbar.dart';
import '../widgets/rounded_card.dart';
import '../services/auth_service.dart';
import 'expenses_page.dart';
import 'settings_page.dart';
import 'dart:math';
import 'manage_households_page.dart';
import 'package:country_flags/country_flags.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

String generateJoinId([int length = 6]) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rand = Random.secure();
  return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
}

class _HomePageState extends State<HomePage> {
  int idx = 0;
  final _auth = AuthService();
  String? _householdId;
  bool _isLoading = true;
  List<DocumentSnapshot> _userHouseholds = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentHousehold();
    _loadHouseholds();
  }

  Future<void> _loadCurrentHousehold() async {
    final user = await _auth.getCurrentUser();
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _householdId = null;
      });
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!mounted) return;

    final householdId = userDoc.data()?['currentHousehold'] as String?;
    setState(() {
      _householdId = householdId;
      _isLoading = false;
    });
  }

  Future<void> _loadHouseholds() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final query = await FirebaseFirestore.instance
        .collection('households')
        .where('members', arrayContains: uid)
        .get();

    if (!mounted) return; 
    setState(() {
      _userHouseholds = query.docs;
    });
  }

  Stream<DocumentSnapshot> getUserStream() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
  }

  Stream<List<DocumentSnapshot>> getUserHouseholdsStream() async* {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    yield* FirebaseFirestore.instance
        .collection('households')
        .where('members', arrayContains: uid)
        .snapshots()
        .map((snap) => snap.docs);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: getUserStream(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
        final currentHouseholdId = userData?['currentHousehold'] as String?;

        return StreamBuilder<List<DocumentSnapshot>>(
          stream: getUserHouseholdsStream(),
          builder: (context, householdsSnapshot) {
            if (!householdsSnapshot.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final userHouseholds = householdsSnapshot.data!;
            final householdExists = userHouseholds.any((h) => h.id == currentHouseholdId);

            final pages = [
              householdExists
                  ? _Dashboard(householdId: currentHouseholdId!)
                  : _noHouseholdContent(context, userHouseholds),
              // Expenses tab
              householdExists
                  ? ExpensesPage(householdId: currentHouseholdId!)
                  : _noHouseholdContent(context, userHouseholds),
              const SettingsPage(),
            ];

            return Scaffold(
              appBar: AppBar(
                centerTitle: true,
                title: idx == 0 || idx == 1
                    ? (householdExists
                        ? StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('households')
                                .doc(currentHouseholdId)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || !snapshot.data!.exists) {
                                return const Text('Household');
                              }
                              final data = snapshot.data!.data() as Map<String, dynamic>;
                              final householdName = data['name'] ?? 'Household';
                              return GestureDetector(
                                onTap: () => _showHouseholdSelector(context),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      householdName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_drop_down,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                        : const Text("Home"))
                    : const Text("Settings"),
              ),
              body: SafeArea(child: pages[idx]),
              bottomNavigationBar: FancyNavBar(
                currentIndex: idx,
                onTap: (i) => setState(() => idx = i),
              ),
            );
          },
        );
      },
    );
  }

  /// Widget to show create/join buttons when no household
  Widget _noHouseholdContent(BuildContext context, List<DocumentSnapshot> userHouseholds) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("You are not in any household"),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _showCreateHouseholdDialog(context),
            child: const Text("Create Household"),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _showJoinHouseholdDialog(context),
            child: const Text("Join Household"),
          ),
        ],
      ),
    );
  }


  /// Household dropdown as a modal bottom sheet
  void _showHouseholdSelector(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    showModalBottomSheet(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      context: context,
      builder: (context) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('households')
              .where('members', arrayContains: uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final households = snapshot.data!.docs;

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Switch Household",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  ...households.map((h) => ListTile(
                        title: Text(h['name']),
                        onTap: () async {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .update({'currentHousehold': h.id});
                          setState(() => _householdId = h.id);
                          Navigator.pop(context);
                        },
                      )),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text("Manage Households"),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ManageHouseholdsPage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.add_home),
                    title: const Text("Add Household"),
                    onTap: () {
                      Navigator.pop(context);
                      _showCreateHouseholdDialog(context);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  /// Dialog to create a household
  void _showCreateHouseholdDialog(BuildContext context) {
    final nameController = TextEditingController();
    final budgetController = TextEditingController();
    final pinController = TextEditingController();

    // Auto-detect currency
    final locale = Localizations.localeOf(context);
    String selectedCurrency = _currencyFromCountry(locale.countryCode);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Create Household"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Household Name"),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedCurrency,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: "Currency",
                  contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                ),
                items: _currencyList.map((currency) {
                  return DropdownMenuItem<String>(
                    value: currency['code'],
                    child: Row(
                      children: [
                        CountryFlag.fromCountryCode(
                          currency.containsKey('countryCode')
                              ? currency['countryCode']!
                              : currency['code']!,
                          height: 18,
                          width: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${currency['code']} - ${currency['name']}",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => selectedCurrency = value ?? selectedCurrency);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: budgetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Monthly Budget (optional)",
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pinController,
                decoration: const InputDecoration(labelText: "PIN"),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final pin = pinController.text.trim();
              final budget = budgetController.text.trim();

              if (name.isEmpty || pin.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter both name and PIN")),
                );
                return;
              }

              final uid = FirebaseAuth.instance.currentUser!.uid;
              final joinId = generateJoinId(); // helper function above
              final docRef = FirebaseFirestore.instance.collection('households').doc();

              await docRef.set({
                'id': docRef.id,
                'name': name,
                'currency': selectedCurrency,
                'budget': budget.isNotEmpty ? double.parse(budget) : null,
                'pin': pin,
                'joinId': joinId,
                'createdBy': uid,
                'members': [uid],
                'createdAt': FieldValue.serverTimestamp(),
              });

              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .update({'currentHousehold': docRef.id});

              setState(() => _householdId = docRef.id);
              Navigator.pop(context);
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  /// Helper to map country code -> currency code
  String _currencyFromCountry(String? countryCode) {
    if (countryCode == null) return "USD";
    switch (countryCode.toUpperCase()) {
      case "US": return "USD";
      case "GB": return "GBP";
      case "EU": case "FR": case "DE": case "IT": case "ES": return "EUR";
      case "JP": return "JPY";
      case "AU": return "AUD";
      case "CA": return "CAD";
      case "CH": return "CHF";
      case "CN": return "CNY";
      case "IN": return "INR";
      case "PK": return "PKR";
      case "SA": return "SAR";
      case "NZ": return "NZD";
      case "MX": return "MXN";
      case "BR": return "BRL";
      case "RU": return "RUB";
      case "ZA": return "ZAR";
      case "SG": return "SGD";
      case "KR": return "KRW";
      case "TR": return "TRY";
      case "AE": return "AED";
      default: return "USD";
    }
  }

/// Currency options (with country codes for flags)
  final List<Map<String, String>> _currencyList = [
    {"code": "USD", "name": "US Dollar", "countryCode": "US"},
    {"code": "EUR", "name": "Euro", "countryCode": "DE"},
    {"code": "GBP", "name": "British Pound", "countryCode": "GB"},
    {"code": "JPY", "name": "Japanese Yen", "countryCode": "JP"},
    {"code": "AUD", "name": "Australian Dollar", "countryCode": "AU"},
    {"code": "CAD", "name": "Canadian Dollar", "countryCode": "CA"},
    {"code": "CHF", "name": "Swiss Franc", "countryCode": "CH"},
    {"code": "CNY", "name": "Chinese Yuan", "countryCode": "CN"},
    {"code": "INR", "name": "Indian Rupee", "countryCode": "IN"},
    {"code": "PKR", "name": "Pakistani Rupee", "countryCode": "PK"},
    {"code": "SAR", "name": "Saudi Riyal", "countryCode": "SA"},
    {"code": "NZD", "name": "New Zealand Dollar", "countryCode": "NZ"},
    {"code": "MXN", "name": "Mexican Peso", "countryCode": "MX"},
    {"code": "BRL", "name": "Brazilian Real", "countryCode": "BR"},
    {"code": "RUB", "name": "Russian Ruble", "countryCode": "RU"},
    {"code": "ZAR", "name": "South African Rand", "countryCode": "ZA"},
    {"code": "SGD", "name": "Singapore Dollar", "countryCode": "SG"},
    {"code": "KRW", "name": "South Korean Won", "countryCode": "KR"},
    {"code": "TRY", "name": "Turkish Lira", "countryCode": "TR"},
    {"code": "AED", "name": "UAE Dirham", "countryCode": "AE"},
  ];

  void _showJoinHouseholdDialog(BuildContext context) {
    final joinIdController = TextEditingController();
    final pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Join Household"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: joinIdController,
              decoration: const InputDecoration(labelText: "Join ID"),
            ),
            TextField(
              controller: pinController,
              decoration: const InputDecoration(labelText: "PIN"),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final joinId = joinIdController.text.trim();
              final pin = pinController.text.trim();

              if (joinId.isEmpty || pin.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter both Join ID and PIN")),
                );
                return;
              }

              try {
                final query = await FirebaseFirestore.instance
                    .collection('households')
                    .where('joinId', isEqualTo: joinId)
                    .limit(1)
                    .get();

                if (query.docs.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("No household found")),
                  );
                  return;
                }

                final doc = query.docs.first;
                final data = doc.data();

                if (data['pin'] != pin) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Incorrect PIN")),
                  );
                  return;
                }

                final uid = FirebaseAuth.instance.currentUser!.uid;

                await doc.reference.update({
                  'members': FieldValue.arrayUnion([uid])
                });

                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .update({'currentHousehold': doc.id});

                setState(() => _householdId = doc.id);
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e")),
                );
              }
            },
            child: const Text("Join"),
          ),
        ],
      ),
    );
  }
}


Widget _buildCategoryBar(BuildContext context, String name, double value, double total) {
  final percent = total == 0 ? 0.0 : (value / total);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$name - ${(percent * 100).toStringAsFixed(1)}%'),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percent,
          color: AppThemes.primaryGradient(dark: Theme.of(context).brightness == Brightness.dark).colors.first,
          backgroundColor: Colors.grey.withOpacity(0.2),
          minHeight: 8,
        ),
      ],
    ),
  );
}

class _Dashboard extends StatefulWidget {
  final String householdId;
  const _Dashboard({required this.householdId});

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  bool _isFabExpanded = false;

  final _expenseAmountController = TextEditingController();
  final _expenseCategoryController = TextEditingController();
  final _expenseLocationController = TextEditingController();
  final _expenseDescriptionController = TextEditingController();

  double _budget = 0.0;

  String _timeline = 'Month'; // default
  final List<String> _timelineOptions = ['Day', 'Week', 'Month', '3 Months', '6 Months', 'Year', 'All Time'];

  final List<String> _categories = [
    "Groceries",
    "Utilities",
    "Transport",
    "Entertainment",
    "Dining",
    "Other"
  ];

  String _currentMonthYear = DateFormat('MMMM yyyy').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _fetchHouseholdData();
  }

  DateTime _getStartDate() {
    final now = DateTime.now();
    switch (_timeline) {
      case 'Day':
        return DateTime(now.year, now.month, now.day);
      case 'Week':
        return now.subtract(Duration(days: now.weekday - 1)); // start of week
      case 'Month':
        return DateTime(now.year, now.month, 1);
      case '3 Months':
        return DateTime(now.year, now.month - 2, 1);
      case '6 Months':
        return DateTime(now.year, now.month - 5, 1);
      case 'Year':
        return DateTime(now.year, 1, 1);
      case 'All Time':
        return DateTime(2000); // arbitrary early date
      default:
        return DateTime(now.year, now.month, 1);
    }
  }

  Future<Map<String, double>> _fetchSpendingPerMember() async {
    final start = _getStartDate();
    final householdDoc = await FirebaseFirestore.instance
        .collection('households')
        .doc(widget.householdId)
        .get();

    final memberIds = List<String>.from(householdDoc['members'] ?? []);
    final Map<String, double> spendingMap = {};

    for (String id in memberIds) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(id).get();
      final userName = userDoc.data()?['name'] ?? 'Unknown';

      final expensesQuery = await FirebaseFirestore.instance
          .collection('households')
          .doc(widget.householdId)
          .collection('expenses')
          .where('userId', isEqualTo: id)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .get();

      final totalSpent = expensesQuery.docs.fold<double>(
          0, (sum, doc) => sum + (doc.data()['amount']?.toDouble() ?? 0));

      spendingMap[userName] = totalSpent;
    }

    return spendingMap;
  }


  Future<void> _fetchHouseholdData() async {
    final householdDoc = await FirebaseFirestore.instance
        .collection('households')
        .doc(widget.householdId)
        .get();

    if (householdDoc.exists) {
      setState(() {
        _budget = (householdDoc.data()?['budget'] ?? 0).toDouble();
      });
    }
  }
  @override
  void dispose() {
    _expenseAmountController.dispose();
    _expenseCategoryController.dispose();
    _expenseLocationController.dispose();
    _expenseDescriptionController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _previousMonth() {
    final current = DateFormat('MMMM yyyy').parse(_currentMonthYear);
    final prev = DateTime(current.year, current.month - 1, 1);
    setState(() => _currentMonthYear = DateFormat('MMMM yyyy').format(prev));
  }

  void _nextMonth() {
    final current = DateFormat('MMMM yyyy').parse(_currentMonthYear);
    final next = DateTime(current.year, current.month + 1, 1);
    setState(() => _currentMonthYear = DateFormat('MMMM yyyy').format(next));
  }

  void _showAddExpenseDialog() {
    _expenseAmountController.clear();
    _expenseCategoryController.clear();
    _expenseLocationController.clear();
    _expenseDescriptionController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Expense"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _expenseAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Amount"),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _categories.first,
                items: _categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(cat),
                  );
                }).toList(),
                onChanged: (val) => _expenseCategoryController.text = val ?? _categories.first,
                decoration: const InputDecoration(labelText: "Category"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _expenseLocationController,
                decoration: const InputDecoration(labelText: "Location (optional)"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _expenseDescriptionController,
                decoration: const InputDecoration(labelText: "Description (optional)"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final amountText = _expenseAmountController.text.trim();
              final category = _expenseCategoryController.text.trim().isEmpty
                  ? _categories.first
                  : _expenseCategoryController.text.trim();

              if (amountText.isEmpty || double.tryParse(amountText) == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Enter a valid amount")));
                return;
              }

              final amount = double.parse(amountText);

              await FirebaseFirestore.instance
                  .collection('households')
                  .doc(widget.householdId)
                  .collection('expenses')
                  .add({
                'amount': amount,
                'category': category,
                'location': _expenseLocationController.text.trim(),
                'description': _expenseDescriptionController.text.trim(),
                'userId': FirebaseAuth.instance.currentUser!.uid,
                'timestamp': FieldValue.serverTimestamp(),
              });

              Navigator.pop(context);
              setState(() => _isFabExpanded = false);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  IconData _iconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'groceries':
        return Icons.local_grocery_store_rounded;
      case 'utilities':
        return Icons.payments_rounded;
      case 'transport':
        return Icons.directions_car_rounded;
      case 'entertainment':
        return Icons.movie_rounded;
      case 'restaurants':
      case 'dining':
        return Icons.restaurant_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    final monthStart = DateTime.parse(
        DateFormat('yyyy-MM').format(DateFormat('MMMM yyyy').parse(_currentMonthYear)) +
            '-01');
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 0, 23, 59, 59);

    final expensesStream = FirebaseFirestore.instance
        .collection('households')
        .doc(widget.householdId)
        .collection('expenses')
        .where('timestamp', isGreaterThanOrEqualTo: monthStart)
        .where('timestamp', isLessThanOrEqualTo: monthEnd)
        .orderBy('timestamp', descending: true)
        .snapshots();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: expensesStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final expenses = snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return {
                'amount': (data['amount'] ?? 0).toDouble(),
                'category': data['category'] ?? 'Other',
                'timestamp': (data['timestamp'] as Timestamp).toDate(),
                'description': data['description'] ?? '',
                'location': data['location'] ?? '',
              };
            }).toList();

            final totalSpent = expenses.fold<double>(0, (sum, e) => sum + e['amount']);

            // Category totals
            final Map<String, double> categoryTotals = {};
            for (var e in expenses) {
              final cat = e['category'] as String;
              categoryTotals[cat] = (categoryTotals[cat] ?? 0) + (e['amount'] as double);
            }

            return ListView(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUserId)
                            .get(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Text('Loading...',
                                style: Theme.of(context).textTheme.titleLarge);
                          }
                          final userData =
                              snapshot.data!.data() as Map<String, dynamic>?;
                          final userName = userData?['name'] ?? 'User';
                          return Text(
                            '${_getGreeting()}, $userName',
                            style: Theme.of(context).textTheme.titleLarge,
                          );
                        },
                      ),
                    ]),
                    GestureDetector(
                      onTap: () async {
                        final householdDoc = await FirebaseFirestore.instance
                            .collection('households')
                            .doc(widget.householdId)
                            .get();

                        final memberIds =
                            List<String>.from(householdDoc['members'] ?? []);
                        final memberDocs = await Future.wait(memberIds.map(
                          (id) => FirebaseFirestore.instance
                              .collection('users')
                              .doc(id)
                              .get(),
                        ));
                        final members = memberDocs
                            .map((doc) => doc.data()?['name'] ?? "Unknown")
                            .toList();

                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Household Members'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children:
                                  members.map((m) => ListTile(title: Text(m))).toList(),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.group_rounded),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 18),

                // Month + category graph card
                RoundedCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Month selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(icon: const Icon(Icons.arrow_back_ios_rounded), onPressed: _previousMonth),
                          Text(_currentMonthYear, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.arrow_forward_ios_rounded), onPressed: _nextMonth),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Bar graph by category
                      SizedBox(
                        height: 180,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: categoryTotals.entries.map((entry) {
                            final cat = entry.key;
                            final spent = entry.value;
                            final percent = _budget > 0 ? (spent / _budget) : 0.0;
                            return Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text('\$${spent.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: percent * 120, // scale max height
                                    decoration: BoxDecoration(
                                      gradient: AppThemes.primaryGradient(
                                          dark: Theme.of(context).brightness == Brightness.dark),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(cat, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Spent / Budget display
                      Text(
                        'Spent: \$${totalSpent.toStringAsFixed(2)} / \$${_budget.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: _budget > 0 ? totalSpent / _budget : 0,
                        backgroundColor: Colors.grey.withOpacity(0.2),
                        color: Theme.of(context).colorScheme.primary,
                        minHeight: 10,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Recent activity + categories
                RoundedCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Recent Activity', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...expenses.take(5).map((e) {
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(child: Icon(_iconForCategory(e['category']))),
                          title: Text(e['category']),
                          subtitle: Text(DateFormat('MMM d').format(e['timestamp'])),
                          trailing: Text('- \$${e['amount'].toStringAsFixed(2)}'),
                        );
                      }).toList(),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text('Spending by Category', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...categoryTotals.entries.map((entry) {
                        return _buildCategoryBar(context, entry.key, entry.value, totalSpent);
                      }).toList(),
                    ],
                  ),
                ),


                const SizedBox(height: 14,),

                RoundedCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timeline selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Spending by Person', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          DropdownButton<String>(
                            value: _timeline,
                            items: _timelineOptions.map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t, style: const TextStyle(fontSize: 14)),
                            )).toList(),
                            onChanged: (val) {
                              setState(() {
                                _timeline = val!;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<Map<String, double>>(
                        future: _fetchSpendingPerMember(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const CircularProgressIndicator();
                          final spending = snapshot.data!;
                          if (spending.isEmpty) return const Text('No spending yet.');

                          return Column(
                            children: spending.entries.map((e) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
                              title: Text(e.key),
                              trailing: Text('\$${e.value.toStringAsFixed(2)}'),
                            )).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Stack(
        children: [
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_isFabExpanded) ...[
                  FloatingActionButton.extended(
                    heroTag: "scanReceipt",
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Scan receipt coming soon!")));
                    },
                    label: const Text("Scan Receipt"),
                    icon: const Icon(Icons.camera_alt_rounded),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton.extended(
                    heroTag: "enterManual",
                    onPressed: _showAddExpenseDialog,
                    label: const Text("Enter Manually"),
                    icon: const Icon(Icons.edit_rounded),
                  ),
                  const SizedBox(height: 12),
                ],
                FloatingActionButton(
                  heroTag: "mainFab",
                  onPressed: () => setState(() => _isFabExpanded = !_isFabExpanded),
                  child: Icon(_isFabExpanded ? Icons.close_rounded : Icons.add),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
