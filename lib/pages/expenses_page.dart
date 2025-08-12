// lib/pages/expenses_page.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExpensesPage extends StatefulWidget {
  final String householdId;
  const ExpensesPage({super.key, required this.householdId});
  @override State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final _auth = AuthService();

  void _addExpenseDialog() {
    final titleCtl = TextEditingController();
    final amountCtl = TextEditingController();
    final catCtl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Add Expense'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: titleCtl, decoration: const InputDecoration(labelText: 'Title')),
        TextField(controller: amountCtl, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number),
        TextField(controller: catCtl, decoration: const InputDecoration(labelText: 'Category')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          final t = titleCtl.text.trim();
          final a = double.tryParse(amountCtl.text.trim()) ?? 0.0;
          final c = catCtl.text.trim();
          await _auth.addExpense(hid: widget.householdId, title: t, amount: a, category: c);
          Navigator.pop(context);
        }, child: const Text('Add'))
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hid = widget.householdId;
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
            stream: _auth.streamExpenses(hid),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) return const Center(child: Text('No expenses yet'));
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i].data();
                  final date = (d['date'] as Timestamp?)?.toDate();
                  return ListTile(
                    title: Text(d['title'] ?? '—'),
                    subtitle: Text('${d['category'] ?? ''} • ${date != null ? date.toLocal().toString().split(' ')[0] : ''}'),
                    trailing: Text('- \$${(d['amount'] ?? 0).toString()}'),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(onPressed: _addExpenseDialog, icon: const Icon(Icons.add), label: const Text('Add Expense')),
        )
      ],
    );
  }
}
