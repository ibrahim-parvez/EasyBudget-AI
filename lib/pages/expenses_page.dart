import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../widgets/rounded_card.dart';
import '../utils/currency_utils.dart';

class ExpensesPage extends StatefulWidget {
  final String householdId;
  const ExpensesPage({super.key, required this.householdId});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  String _currencyCode = "USD"; // fallback

  final _expenseAmountController = TextEditingController();
  final _expenseCategoryController = TextEditingController();
  final _expenseLocationController = TextEditingController();
  final _expenseDescriptionController = TextEditingController();
  final _expenseDateController =
      TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));

  final List<String> _categories = [
    "Groceries",
    "Utilities",
    "Transport",
    "Entertainment",
    "Dining",
    "Other"
  ];

  final Map<String, IconData> _categoryIcons = {
    "Groceries": Icons.local_grocery_store_rounded,
    "Utilities": Icons.payments_rounded,
    "Transport": Icons.directions_car_rounded,
    "Entertainment": Icons.movie_rounded,
    "Dining": Icons.restaurant_rounded,
    "Other": Icons.category_rounded,
  };

  /// Map to store total spent per day
  Map<DateTime, double> _dailySpending = {};

  static const Color primaryBlue = Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    _loadHouseholdCurrency();
    _loadDailySpending();
  }

  @override
  void didUpdateWidget(covariant ExpensesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.householdId != widget.householdId) {
      _loadHouseholdCurrency();
      _loadDailySpending();
    }
  }

  Future<void> _loadHouseholdCurrency() async {
    final doc = await FirebaseFirestore.instance
        .collection('households')
        .doc(widget.householdId)
        .get();

    if (doc.exists) {
      final data = doc.data();
      final code = data?['currency'] ?? "USD";

      setState(() {
        _currencyCode = code;
      });
    }
  }

  void _loadDailySpending() {
    FirebaseFirestore.instance
        .collection('households')
        .doc(widget.householdId)
        .collection('expenses')
        .snapshots()
        .listen((snapshot) {
      final Map<DateTime, double> tempMap = {};
      for (var doc in snapshot.docs) {
        final ts = (doc['timestamp'] as Timestamp?)?.toDate();
        if (ts == null) continue;
        final day = DateTime(ts.year, ts.month, ts.day);
        tempMap[day] = (tempMap[day] ?? 0) + (doc['amount'] ?? 0);
      }
      setState(() {
        _dailySpending = tempMap;
      });
    });
  }

  /// Use CurrencyUtils for symbol
  String _formatCurrency(double amount) {
    final symbol = CurrencyUtils.symbol(_currencyCode);
    final format = NumberFormat.currency(
      name: _currencyCode,
      symbol: symbol,
    );
    return format.format(amount);
  }

  void _showAddExpenseDialog({String? docId, Map<String, dynamic>? data}) {
    if (data != null) {
      _expenseAmountController.text = (data['amount'] ?? '').toString();
      _expenseCategoryController.text = data['category'] ?? _categories.first;
      _expenseLocationController.text = data['location'] ?? '';
      _expenseDescriptionController.text = data['description'] ?? '';
    } else {
      _expenseAmountController.clear();
      _expenseCategoryController.clear();
      _expenseLocationController.clear();
      _expenseDescriptionController.clear();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(docId == null ? "Add Expense" : "Edit Expense"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _expenseAmountController,
                decoration: InputDecoration(
                  labelText: "Amount (${CurrencyUtils.symbol(_currencyCode)})"
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _expenseCategoryController.text.isNotEmpty
                    ? _expenseCategoryController.text
                    : _categories.first,
                items: _categories
                    .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                onChanged: (val) =>
                    _expenseCategoryController.text = val ?? _categories.first,
                decoration: const InputDecoration(labelText: "Category"),
              ),
              const SizedBox(height: 8),
              TextField(
                  controller: _expenseLocationController,
                  decoration:
                      const InputDecoration(labelText: "Location (optional)")),
              const SizedBox(height: 8),
              TextField(
                  controller: _expenseDescriptionController,
                  decoration:
                      const InputDecoration(labelText: "Description (optional)")),
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
          ),
        ),
        actions: [
          if (docId != null)
            TextButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('households')
                    .doc(widget.householdId)
                    .collection('expenses')
                    .doc(docId)
                    .delete();
                Navigator.pop(context);
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final amount =
                  double.tryParse(_expenseAmountController.text.trim()) ?? 0.0;
              final category = _expenseCategoryController.text.trim();
              final location = _expenseLocationController.text.trim();
              final description = _expenseDescriptionController.text.trim();

              final expData = {
                'amount': amount,
                'category': category,
                'location': location,
                'description': description,
                'userId': FirebaseAuth.instance.currentUser!.uid,
                'timestamp': Timestamp.fromDate(
                    DateFormat('yyyy-MM-dd').parse(_expenseDateController.text)),
              };

              final col = FirebaseFirestore.instance
                  .collection('households')
                  .doc(widget.householdId)
                  .collection('expenses');

              if (docId == null) {
                await col.add(expData);
              } else {
                await col.doc(docId).update(expData);
              }

              Navigator.pop(context);
            },
            child: Text(docId == null ? "Add" : "Update"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime(2000),
            lastDay: DateTime(2100),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, _) {
                final spent =
                    _dailySpending[DateTime(day.year, day.month, day.day)] ?? 0;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${day.day}'),
                    if (spent > 0)
                      Text(
                        _formatCurrency(spent),
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                  ],
                );
              },
              todayBuilder: (context, day, _) {
                final spent =
                    _dailySpending[DateTime(day.year, day.month, day.day)] ?? 0;
                return Container(
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${day.day}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (spent > 0)
                        Text(
                          _formatCurrency(spent),
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                );
              },
              selectedBuilder: (context, day, _) {
                final spent =
                    _dailySpending[DateTime(day.year, day.month, day.day)] ?? 0;
                return Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: primaryBlue,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${day.day}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      if (spent > 0)
                        Text(
                          _formatCurrency(spent),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          // EXPENSE LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('households')
                  .doc(widget.householdId)
                  .collection('expenses')
                  .where('timestamp',
                      isGreaterThanOrEqualTo: Timestamp.fromDate(
                          DateTime(_selectedDay.year, _selectedDay.month,
                              _selectedDay.day)))
                  .where('timestamp',
                      isLessThanOrEqualTo: Timestamp.fromDate(DateTime(
                          _selectedDay.year,
                          _selectedDay.month,
                          _selectedDay.day,
                          23,
                          59,
                          59)))
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      "No purchases on ${DateFormat('yMMMd').format(_selectedDay)}",
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }
                return ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    ...docs.map((doc) {
                      final d = doc.data();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () =>
                              _showAddExpenseDialog(docId: doc.id, data: d),
                          child: RoundedCard(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: primaryBlue.withOpacity(0.2),
                                  child: Icon(
                                    _categoryIcons[d['category']] ??
                                        Icons.category_rounded,
                                    color: primaryBlue,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(d['category'] ?? '',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey)),
                                      if ((d['location'] ?? '').isNotEmpty ||
                                          (d['description'] ?? '').isNotEmpty)
                                        Text(
                                          [
                                            if ((d['location'] ?? '').isNotEmpty)
                                              'Location: ${d['location']}',
                                            if ((d['description'] ?? '')
                                                .isNotEmpty)
                                              'Notes: ${d['description']}',
                                          ].join(' • '),
                                          style: const TextStyle(
                                              fontSize: 12, color: Colors.grey),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '- ${_formatCurrency((d['amount'] ?? 0).toDouble())}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 60),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
