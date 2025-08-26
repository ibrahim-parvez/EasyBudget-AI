// lib/pages/subscriptions_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/rounded_card.dart';
import '../utils/currency_utils.dart';

class SubscriptionsPage extends StatelessWidget {
  final String householdId;

  const SubscriptionsPage({super.key, required this.householdId});

  @override
  Widget build(BuildContext context) {
    final subsRef = FirebaseFirestore.instance
        .collection('households')
        .doc(householdId)
        .collection('subscriptions');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Subscriptions"),
        centerTitle: true,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('households')
            .doc(householdId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final householdData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final householdCurrency = householdData['currency'] ?? 'USD';

          return Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: subsRef.orderBy('nextDue').snapshots(),
                  builder: (context, subSnapshot) {
                    if (subSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!subSnapshot.hasData || subSnapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          "No subscriptions yet.\nTap below to add one.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      );
                    }

                    final subs = subSnapshot.data!.docs;

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: subs.length,
                      itemBuilder: (context, i) {
                        final sub = subs[i];
                        final data = sub.data() as Map<String, dynamic>;
                        final name = data['name'] ?? '';
                        final cost = (data['cost'] ?? 0).toDouble();
                        final cycle = data['cycle'] ?? 'Monthly';
                        final nextDue = (data['nextDue'] as Timestamp?)?.toDate();
                        final nextDueStr = nextDue != null
                            ? DateFormat.yMMMd().format(nextDue)
                            : "-";

                        final currency = data['currency'] ?? householdCurrency;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: RoundedCard(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              title: Text(
                                name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text("$cycle • Next due: $nextDueStr"),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "${CurrencyUtils.symbol(currency)}${cost.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        size: 20, color: Colors.blueGrey),
                                    onPressed: () {
                                      _showEditSubscriptionDialog(
                                        context,
                                        sub.reference,
                                        data,
                                        householdCurrency,
                                      );
                                    },
                                  ),
                                ],
                              ),
                              onLongPress: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text("Delete Subscription"),
                                    content:
                                        Text("Remove $name from this household?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text("Cancel"),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text("Delete"),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await sub.reference.delete();
                                }
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text("Add Subscription"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _showAddSubscriptionDialog(
                        context,
                        subsRef,
                        householdCurrency,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddSubscriptionDialog(
    BuildContext context,
    CollectionReference subsRef,
    String householdCurrency,
  ) {
    final nameController = TextEditingController();
    final costController = TextEditingController();
    String cycle = 'Monthly';
    DateTime dueDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Add Subscription"),
            content: _subscriptionForm(
              context,
              nameController,
              costController,
              cycle,
              dueDate,
              (newCycle, newDate) {
                setState(() {
                  cycle = newCycle ?? cycle;
                  dueDate = newDate ?? dueDate;
                });
              },
            ),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: const Text("Save"),
                onPressed: () async {
                  final name = nameController.text.trim();
                  final cost = double.tryParse(costController.text.trim());
                  if (name.isEmpty || cost == null || dueDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Fill all fields correctly")),
                    );
                    return;
                  }

                  // save with household currency
                  await subsRef.add({
                    'name': name,
                    'cost': cost,
                    'cycle': cycle,
                    'nextDue': dueDate,
                    'currency': householdCurrency,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditSubscriptionDialog(
    BuildContext context,
    DocumentReference subRef,
    Map<String, dynamic> data,
    String householdCurrency,
  ) {
    final nameController = TextEditingController(text: data['name']);
    final costController =
        TextEditingController(text: (data['cost'] ?? '').toString());
    String cycle = data['cycle'] ?? 'Monthly';
    DateTime dueDate =
        (data['nextDue'] as Timestamp?)?.toDate() ?? DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Edit Subscription"),
            content: _subscriptionForm(
              context,
              nameController,
              costController,
              cycle,
              dueDate,
              (newCycle, newDate) {
                setState(() {
                  cycle = newCycle ?? cycle;
                  dueDate = newDate ?? dueDate;
                });
              },
            ),
            actions: [
              TextButton(
                child: const Text("Delete", style: TextStyle(color: Colors.red)),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Delete Subscription"),
                      content: Text("Are you sure you want to delete ${nameController.text} Subscription?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text("Delete"),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await subRef.delete();
                    if (context.mounted) Navigator.pop(context); // close edit dialog
                  }
                },
              ),
              TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: const Text("Update"),
                onPressed: () async {
                  final name = nameController.text.trim();
                  final cost = double.tryParse(costController.text.trim());
                  if (name.isEmpty || cost == null || dueDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Fill all fields correctly")),
                    );
                    return;
                  }

                  await subRef.update({
                    'name': name,
                    'cost': cost,
                    'cycle': cycle,
                    'nextDue': dueDate,
                    'currency': data['currency'] ?? householdCurrency,
                  });

                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

Widget _subscriptionForm(
  BuildContext context,
  TextEditingController nameController,
  TextEditingController costController,
  String cycle,
  DateTime? dueDate,
  void Function(String?, DateTime?) onChanged,
) {
  return SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: "Name"),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: costController,
          decoration: const InputDecoration(labelText: "Cost"),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: cycle,
          decoration: const InputDecoration(labelText: "Billing Cycle"),
          items: const [
            DropdownMenuItem(value: "Monthly", child: Text("Monthly")),
            DropdownMenuItem(value: "Annual", child: Text("Annual")),
          ],
          onChanged: (val) => onChanged(val, dueDate),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                dueDate == null
                    ? "Pick next due date"
                    : "Next due: ${DateFormat.yMMMd().format(dueDate)}",
              ),
            ),
            IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: dueDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  onChanged(cycle, picked);
                }
              },
            ),
          ],
        ),
      ],
    ),
  );
}
