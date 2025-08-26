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
import '../main.dart';
import '../services/expense_scanner_service.dart';
import 'subscriptions_page.dart';
import 'dart:io';
import '../utils/currency_utils.dart';


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
  bool _isFabExpanded = false;

    final List<String> _categories = [
    "Groceries",
    "Utilities",
    "Transport",
    "Entertainment",
    "Dining",
    "Other"
  ];

  // Add these controllers for expense input fields
  final TextEditingController _expenseAmountController = TextEditingController();
  final TextEditingController _expenseCategoryController = TextEditingController();
  final TextEditingController _expenseDateController = TextEditingController();
  final TextEditingController _expenseLocationController = TextEditingController();
  final TextEditingController _expenseDescriptionController = TextEditingController();

  void _showAddExpenseDialog({
    String? amount,
    String? category,
    String? location,
    String? description,
    String? date,
    String? receiptImagePath,
    bool isLoading = false,
  }) {
    if (amount != null) _expenseAmountController.text = amount;
    if (category != null) _expenseCategoryController.text = category;
    if (location != null) _expenseLocationController.text = location;
    if (description != null) _expenseDescriptionController.text = description;
    if (date != null) _expenseDateController.text = date;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Add Expense"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (receiptImagePath != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Image.file(
                        File(receiptImagePath),
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  if (isLoading) const CircularProgressIndicator(),
                  if (!isLoading) ...[
                    TextField(
                      controller: _expenseAmountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Amount"),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _expenseCategoryController.text.isNotEmpty
                          ? _expenseCategoryController.text
                          : _categories.first,
                      items: _categories.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(cat),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          _expenseCategoryController.text = val ?? _categories.first,
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
                    const SizedBox(height: 8),
                    TextField(
                      controller: _expenseDateController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: "Date",
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          _expenseDateController.text =
                              DateFormat('yyyy-MM-dd').format(pickedDate);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              if (!isLoading)
                ElevatedButton(
                  onPressed: () async {
                    final amountText = _expenseAmountController.text.trim();
                    final category = _expenseCategoryController.text.trim().isEmpty
                        ? _categories.first
                        : _expenseCategoryController.text.trim();

                    if (amountText.isEmpty || double.tryParse(amountText) == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Enter a valid amount")),
                      );
                      return;
                    }

                    final amount = double.parse(amountText);

                    await FirebaseFirestore.instance
                        .collection('households')
                        .doc(_householdId)
                        .collection('expenses')
                        .add({
                      'amount': amount,
                      'category': category,
                      'location': _expenseLocationController.text.trim(),
                      'description': _expenseDescriptionController.text.trim(),
                      'userId': FirebaseAuth.instance.currentUser!.uid,
                      'timestamp': Timestamp.fromDate(
                        DateFormat('yyyy-MM-dd').parse(_expenseDateController.text),
                      ),
                      if (receiptImagePath != null) 'receiptImage': receiptImagePath,
                    });

                    Navigator.pop(context);
                    setState(() => _isFabExpanded = false);
                  },
                  child: const Text("Add"),
                ),
            ],
          );
        },
      ),
    );
  }

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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // not signed in yet
    final uid = user.uid;

    final query = await FirebaseFirestore.instance
        .collection('households')
        .where('members', arrayContains: uid)
        .get();

    if (!mounted) return;
    setState(() {
      _userHouseholds = query.docs;
    });
  }

  Stream<DocumentSnapshot>? getUserStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null; // not signed in
    return FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots();
  }

  Stream<List<DocumentSnapshot>>? getUserHouseholdsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null; // not signed in
    return FirebaseFirestore.instance
        .collection('households')
        .where('members', arrayContains: user.uid)
        .snapshots()
        .map((snap) => snap.docs);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: getUserStream(),
      builder: (context, userSnapshot) {
        if (getUserStream() == null) {
          return const AuthGate();
        }

        if (!userSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
        final currentHouseholdId = userData?['currentHousehold'] as String?;

        return StreamBuilder<List<DocumentSnapshot>>(
          stream: getUserHouseholdsStream(),
          builder: (context, householdsSnapshot) {
            if (!householdsSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final userHouseholds = householdsSnapshot.data!;
            final householdExists = userHouseholds.any((h) => h.id == currentHouseholdId);

            final pages = [
              householdExists
                  ? _Dashboard(householdId: currentHouseholdId!)
                  : _noHouseholdContent(context, userHouseholds),
              householdExists
                  ? ExpensesPage(householdId: currentHouseholdId!)
                  : _noHouseholdContent(context, userHouseholds),
              Container(), // placeholder for FAB
              SubscriptionsPage(householdId: currentHouseholdId!),
              const SettingsPage(),
            ];

            return Scaffold(
              appBar: AppBar(
                centerTitle: true,
                title: idx == 0 || idx == 1 || idx == 3
                    ? StreamBuilder<DocumentSnapshot>(
                        stream: householdExists
                            ? FirebaseFirestore.instance
                                .collection('households')
                                .doc(currentHouseholdId)
                                .snapshots()
                            : null,
                        builder: (context, snapshot) {
                          if (!householdExists) return const Text("Home", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18));
                          if (!snapshot.hasData || !snapshot.data!.exists) {
                            return const Text('Household', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18));
                          }
                          final data = snapshot.data!.data() as Map<String, dynamic>;
                          final householdName = data['name'] ?? 'Household';
                          return GestureDetector(
                            onTap: () => _showHouseholdSelector(context),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(householdName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                Icon(Icons.arrow_drop_down, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                              ],
                            ),
                          );
                        },
                      )
                    : const Text("Settings"),
                leading: Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: Image.asset(
                    Theme.of(context).brightness == Brightness.dark
                        ? 'assets/images/logo_no_background_dark.png'
                        : 'assets/images/logo_no_background_light.png',
                    height: 70,
                    width: 70,
                  ),
                ),
              ),
              body: SafeArea(child: pages[idx]),
              bottomNavigationBar: FancyNavBar(
                currentIndex: idx,
                onTap: (i) => setState(() => idx = i),
                onScanExpense: () async {
                  final result = await ExpenseScannerService.instance.scanExpense(context);
                  if (result != null) {
                    _expenseAmountController.text = result['amount']?.toString() ?? '';
                    _expenseCategoryController.text = result['category'] ?? '';
                    _expenseDateController.text = result['date'] ?? DateTime.now().toIso8601String().split('T').first;
                    _expenseLocationController.text = result['location'] ?? '';
                    _expenseDescriptionController.text = result['description'] ?? '';
                  }
                  _showAddExpenseDialog();
                },
                onManualExpense: () => _showAddExpenseDialog(),
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

  static const Color primaryBlue = Color(0xFF1565C0);

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

  final TextEditingController _expenseDateController =
    TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));

  // Currency state
  String _currencyCode = 'USD';
  String _currencySymbol = '\$';

  @override
  void initState() {
    super.initState();
    _fetchHouseholdData();
  }

  @override
  void didUpdateWidget(covariant _Dashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.householdId != widget.householdId) {
      _fetchHouseholdData();
    }
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

    if (!mounted) return;

    if (householdDoc.exists) {
      final data = householdDoc.data() ?? {};
      final code = (data['currency'] ?? 'USD').toString();

      final symbol = CurrencyUtils.symbol(code);

      setState(() {
        _budget = (data['budget'] ?? 0).toDouble();
        _currencyCode = code;
        _currencySymbol = symbol;
      });
    }
  }

  @override
  void dispose() {
    _expenseAmountController.dispose();
    _expenseCategoryController.dispose();
    _expenseLocationController.dispose();
    _expenseDescriptionController.dispose();
    _expenseDateController.dispose();
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

  void _showAddExpenseDialog({
    String? amount,
    String? category,
    String? location,
    String? description,
    String? date,
    String? receiptImagePath,
    bool isLoading = false,
  }) {
    if (amount != null) _expenseAmountController.text = amount;
    if (category != null) _expenseCategoryController.text = category;
    if (location != null) _expenseLocationController.text = location;
    if (description != null) _expenseDescriptionController.text = description;
    if (date != null) _expenseDateController.text = date;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Add Expense"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (receiptImagePath != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Image.file(
                        File(receiptImagePath),
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  if (isLoading) const CircularProgressIndicator(),
                  if (!isLoading) ...[
                    TextField(
                      controller: _expenseAmountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: "Amount ($_currencySymbol)"),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _expenseCategoryController.text.isNotEmpty
                          ? _expenseCategoryController.text
                          : _categories.first,
                      items: _categories.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(cat),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          _expenseCategoryController.text = val ?? _categories.first,
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
                    const SizedBox(height: 8),
                    TextField(
                      controller: _expenseDateController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: "Date",
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          _expenseDateController.text =
                              DateFormat('yyyy-MM-dd').format(pickedDate);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              if (!isLoading)
                ElevatedButton(
                  onPressed: () async {
                    final amountText = _expenseAmountController.text.trim();
                    final category = _expenseCategoryController.text.trim().isEmpty
                        ? _categories.first
                        : _expenseCategoryController.text.trim();

                    if (amountText.isEmpty || double.tryParse(amountText) == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Enter a valid amount")),
                      );
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
                      'timestamp': Timestamp.fromDate(
                        DateFormat('yyyy-MM-dd').parse(_expenseDateController.text),
                      ),
                      if (receiptImagePath != null) 'receiptImage': receiptImagePath,
                    });

                    Navigator.pop(context);
                    setState(() => _isFabExpanded = false);
                  },
                  child: const Text("Add"),
                ),
            ],
          );
        },
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

  Widget _buildCategoryBar(BuildContext context, String title, double value, double total) {
    final percent = total > 0 ? (value / total) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(title, style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: percent.clamp(0.0, 1.0),
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: AppThemes.primaryGradient(
                        dark: Theme.of(context).brightness == Brightness.dark,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(
              '$_currencySymbol${value.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
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
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.normal, // remove bold
                                ),
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
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0), // <-- spacing between bars
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      '$_currencySymbol${spent.toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: percent * 120,
                                      decoration: BoxDecoration(
                                        gradient: AppThemes.primaryGradient(
                                          dark: Theme.of(context).brightness == Brightness.dark
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(cat, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Spent / Budget display
                      Text(
                        'Spent: $_currencySymbol${totalSpent.toStringAsFixed(2)} / $_currencySymbol${_budget.toStringAsFixed(2)}',
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
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12), // spacing between cards
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: primaryBlue.withOpacity(0.2),
                                child: Icon(
                                  _iconForCategory(e['category']),
                                  color: primaryBlue,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e['category'],
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                    Text(
                                      DateFormat('MMM d').format(e['timestamp']),
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '- $_currencySymbol${e['amount'].toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: primaryBlue,
                                ),
                              ),
                            ],
                          ),
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
                              trailing: Text('$_currencySymbol${e.value.toStringAsFixed(2)}'),
                            )).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 50),
                // Optional label for branding
                Center(
                  child: Text(
                    "EasyBudget AI",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

