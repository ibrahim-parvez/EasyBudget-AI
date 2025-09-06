import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/currency_utils.dart';
import 'package:country_flags/country_flags.dart';
import '../main.dart';

class ManageHouseholdsPage extends StatefulWidget {
  const ManageHouseholdsPage({super.key});

  @override
  State<ManageHouseholdsPage> createState() => _ManageHouseholdsPageState();
}

class _ManageHouseholdsPageState extends State<ManageHouseholdsPage> {
  final firestore = FirebaseFirestore.instance;
  final uid = FirebaseAuth.instance.currentUser!.uid;
  String? expandedHouseholdId;
  bool isLoading = true;
  List<QueryDocumentSnapshot> households = [];
  Map<String, String> userNames = {};
  String? _householdId;

  String generateJoinId([int length = 6]) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

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

  @override
  void initState() {
    super.initState();
    _loadHouseholdsAndMembers();
  }

  Future<void> _loadHouseholdsAndMembers() async {
    setState(() => isLoading = true);

    final hhSnapshot = await firestore
        .collection('households')
        .where('members', arrayContains: uid)
        .get();

    households = hhSnapshot.docs;

    final allMemberIds = <String>{};
    for (var doc in households) {
      final data = doc.data() as Map<String, dynamic>;
      final members = List<String>.from(data['members'] ?? []);
      allMemberIds.addAll(members);
    }

    if (allMemberIds.isNotEmpty) {
      final usersSnapshot = await firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: allMemberIds.toList())
          .get();

      userNames = {
        for (var uDoc in usersSnapshot.docs)
          uDoc.id: (uDoc.data()['name'] ?? uDoc.data()['email'] ?? uDoc.id) as String
      };
    }

    setState(() => isLoading = false);
  }

  Future<void> _removeMember(String householdId, String memberId) async {
    await firestore.collection('households').doc(householdId).update({
      'members': FieldValue.arrayRemove([memberId]),
    });
    await _loadHouseholdsAndMembers();
  }

  Future<void> _deleteHousehold(String hhId) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Delete the household
    await FirebaseFirestore.instance.collection('households').doc(hhId).delete();

    // Fetch all remaining households for this user
    final userHouseholdsQuery = await FirebaseFirestore.instance
        .collection('households')
        .where('members', arrayContains: uid)
        .get();

    final remainingHouseholds = userHouseholdsQuery.docs;

    if (remainingHouseholds.isNotEmpty) {
      // Automatically switch to the first remaining household
      final newHouseholdId = remainingHouseholds.first.id;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'currentHousehold': newHouseholdId,
      });
      setState(() => _householdId = newHouseholdId);
    } else {
      // No households left
      setState(() => _householdId = null);
    }

    // Reload households and members
    await _loadHouseholdsAndMembers();
  }


  void _showCreateHouseholdDialog() {
    final nameController = TextEditingController();
    final budgetController = TextEditingController();
    final pinController = TextEditingController();

    // Use navigatorKey.currentContext! for a guaranteed valid Navigator context
    final context = navigatorKey.currentContext!;
    
    // Auto-detect currency
    final locale = Localizations.localeOf(context);
    String selectedCurrency = _currencyFromCountry(locale.countryCode);

    showDialog(
      context: context, // always valid
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isLoading = false;

        return StatefulBuilder(
          builder: (dialogContext, setState) => AlertDialog(
            title: const Text("Create Household"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(),
                    )
                  else ...[
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
                      decoration: const InputDecoration(labelText: "Monthly Budget (optional)"),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: pinController,
                      decoration: const InputDecoration(labelText: "PIN"),
                      obscureText: true,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (!isLoading)
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text("Cancel"),
                ),
              if (!isLoading)
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

                    setState(() => isLoading = true);

                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) return;
                      final uid = user.uid;

                      final joinId = generateJoinId();
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

                      if (!mounted) return;
                      setState(() => _householdId = docRef.id);

                      await _loadHouseholdsAndMembers();

                      Navigator.of(dialogContext).pop(); // close dialog
                    } catch (e) {
                      setState(() => isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error: $e")),
                      );
                    }
                  },
                  child: const Text("Create"),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showJoinHouseholdDialog() {
    final joinIdController = TextEditingController();
    final pinController = TextEditingController();

    // Stable context for SnackBars
    final scaffoldContext = ScaffoldMessenger.of(navigatorKey.currentContext!).context;

    showDialog(
      context: navigatorKey.currentContext!, // always valid
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isLoading = false;

        return StatefulBuilder(
          builder: (dialogContext, setState) => AlertDialog(
            title: const Text("Join Household"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(),
                  )
                else ...[
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
              ],
            ),
            actions: [
              if (!isLoading)
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text("Cancel"),
                ),
              if (!isLoading)
                ElevatedButton(
                  onPressed: () async {
                    final joinId = joinIdController.text.trim();
                    final pin = pinController.text.trim();

                    if (joinId.isEmpty || pin.isEmpty) {
                      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                        const SnackBar(content: Text("Please enter both Join ID and PIN")),
                      );
                      return;
                    }

                    setState(() => isLoading = true);

                    try {
                      final query = await FirebaseFirestore.instance
                          .collection('households')
                          .where('joinId', isEqualTo: joinId)
                          .limit(1)
                          .get();

                      if (query.docs.isEmpty) {
                        if (mounted) setState(() => isLoading = false);
                        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                          const SnackBar(content: Text("No household found")),
                        );
                        return;
                      }

                      final doc = query.docs.first;
                      final data = doc.data();

                      if (data['pin'] != pin) {
                        if (mounted) setState(() => isLoading = false);
                        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                          const SnackBar(content: Text("Incorrect PIN")),
                        );
                        return;
                      }

                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) return;
                      final uid = user.uid;

                      await doc.reference.update({
                        'members': FieldValue.arrayUnion([uid])
                      });

                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .update({'currentHousehold': doc.id});

                      if (!mounted) return;
                      Navigator.of(dialogContext).pop(); // safely close dialog
                    } catch (e) {
                      if (mounted) setState(() => isLoading = false);
                      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                        SnackBar(content: Text("Error: $e")),
                      );
                    }
                  },
                  child: const Text("Join"),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _leaveHousehold(String hhId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final firestore = FirebaseFirestore.instance;

    try {
      // 1️⃣ Remove user from household members array
      await firestore.collection('households').doc(hhId).update({
        'members': FieldValue.arrayRemove([uid]),
      });

      // 2️⃣ Delete all expenses created by this user in this household
      final expensesSnapshot = await firestore
          .collection('households')
          .doc(hhId)
          .collection('expenses')
          .where('createdBy', isEqualTo: uid)
          .get();

      final batch = firestore.batch();
      for (final doc in expensesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      // 3️⃣ Optional: if the user has recurring subscriptions or shared data,
      // handle that as needed (e.g., remove from 'subscriptions' collection)

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You have left the household successfully.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error leaving household: $e")),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Households")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : households.isEmpty
              ? const Center(child: Text("No households found"))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: households.length,
                        itemBuilder: (context, index) {
                          final doc = households[index];
                          final hhId = doc.id;
                          final data = doc.data() as Map<String, dynamic>;
                          final hhName = data['name'] ?? "Unnamed Household";
                          final joinId = data['joinId'] ?? "N/A";
                          final members = List<String>.from(data['members'] ?? []);
                          final createdBy = data['createdBy'] ?? '';
                          final isOwner = createdBy == uid;

                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  title: Text(
                                    hhName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                                  subtitle: Text(
                                    isOwner ? "Owner" : "Member",
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                  ),
                                  trailing: Icon(
                                    expandedHouseholdId == hhId
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                  ),
                                  onTap: () {
                                    setState(() {
                                      expandedHouseholdId =
                                          expandedHouseholdId == hhId ? null : hhId;
                                    });
                                  },
                                ),
                                if (expandedHouseholdId == hhId)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Join ID: $joinId",
                                          style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(height: 8),
                                        ...members.map((mId) {
                                          final displayName = userNames[mId] ?? mId;
                                          final memberIsOwner = mId == createdBy;
                                          return ListTile(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            leading: const Icon(Icons.person, size: 20),
                                            title: Text(displayName, style: const TextStyle(fontSize: 14)),
                                            subtitle: Text(
                                              memberIsOwner ? "Owner" : "Member",
                                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                            ),
                                            trailing: isOwner && mId != uid
                                                ? IconButton(
                                                    icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                                                    onPressed: () async {
                                                      final confirm = await showDialog<bool>(
                                                        context: context,
                                                        builder: (context) => AlertDialog(
                                                          title: const Text("Remove Member"),
                                                          content: Text("Remove $displayName from $hhName?"),
                                                          actions: [
                                                            TextButton(
                                                              child: const Text("Cancel"),
                                                              onPressed: () => Navigator.pop(context, false),
                                                            ),
                                                            TextButton(
                                                              child: const Text("Remove", style: TextStyle(color: Colors.red)),
                                                              onPressed: () => Navigator.pop(context, true),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                      if (confirm == true) {
                                                        await _removeMember(hhId, mId);
                                                      }
                                                    },
                                                  )
                                                : null,
                                          );
                                        }),
                                        const SizedBox(height: 8),

                                        // Household Budget
                                        Row(
                                          children: [
                                            Text(
                                              "Monthly Budget: ",
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                              ),
                                            ),
                                            if (isOwner)
                                              GestureDetector(
                                                onTap: () async {
                                                  final budgetController = TextEditingController(
                                                    text: (data['budget'] ?? '').toString(),
                                                  );

                                                  await showDialog(
                                                    context: context,
                                                    builder: (_) => AlertDialog(
                                                      title: const Text("Edit Household Budget"),
                                                      content: TextField(
                                                        controller: budgetController,
                                                        keyboardType: TextInputType.number,
                                                        decoration: const InputDecoration(
                                                          labelText: "Budget",
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          child: const Text("Cancel"),
                                                          onPressed: () => Navigator.pop(context),
                                                        ),
                                                        ElevatedButton(
                                                          child: const Text("Save"),
                                                          onPressed: () async {
                                                            final newBudget =
                                                                double.tryParse(budgetController.text.trim());
                                                            if (newBudget == null) {
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                const SnackBar(
                                                                  content: Text("Enter a valid number"),
                                                                ),
                                                              );
                                                              return;
                                                            }
                                                            await firestore
                                                                .collection('households')
                                                                .doc(hhId)
                                                                .update({'budget': newBudget});
                                                            Navigator.pop(context);
                                                            await _loadHouseholdsAndMembers();
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      "\$${(data['budget'] ?? 0).toStringAsFixed(2)}",
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                        color: Theme.of(context).colorScheme.primary, // nice accent color
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    const Icon(
                                                      Icons.edit,
                                                      size: 16,
                                                      color: Colors.grey, // subtle edit icon
                                                    ),
                                                  ],
                                                ),
                                              )
                                            else
                                              Text(
                                                "\$${(data['budget'] ?? 0).toStringAsFixed(2)}",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Theme.of(context).textTheme.bodyMedium?.color,
                                                ),
                                              ),
                                          ],
                                        ),


                                        const SizedBox(height: 8),
                                        if (isOwner) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              OutlinedButton.icon(
                                                icon: const Icon(Icons.lock_open, size: 18),
                                                label: const Text("Show / Change PIN"),
                                                onPressed: () async {
                                                  final pinController = TextEditingController(text: data['pin'] ?? '');
                                                  await showDialog(
                                                    context: context,
                                                    builder: (_) => AlertDialog(
                                                      title: const Text("Household PIN"),
                                                      content: TextField(
                                                        controller: pinController,
                                                        decoration: const InputDecoration(labelText: "PIN"),
                                                        obscureText: false,
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          child: const Text("Close"),
                                                          onPressed: () => Navigator.pop(context),
                                                        ),
                                                        ElevatedButton(
                                                          child: const Text("Save"),
                                                          onPressed: () async {
                                                            final newPin = pinController.text.trim();
                                                            if (newPin.isEmpty) {
                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                const SnackBar(content: Text("PIN cannot be empty")),
                                                              );
                                                              return;
                                                            }
                                                            await firestore.collection('households').doc(hhId).update({
                                                              'pin': newPin,
                                                            });
                                                            Navigator.pop(context);
                                                            await _loadHouseholdsAndMembers();
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                              const Spacer(),
                                              OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.red,
                                                  side: const BorderSide(color: Colors.red),
                                                ),
                                                icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                                label: const Text("Delete"),
                                                onPressed: () async {
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      title: const Text("Delete Household"),
                                                      content: Text("Delete $hhName for all members?"),
                                                      actions: [
                                                        TextButton(
                                                          child: const Text("Cancel"),
                                                          onPressed: () => Navigator.pop(context, false),
                                                        ),
                                                        TextButton(
                                                          child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                                          onPressed: () => Navigator.pop(context, true),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm == true) {
                                                    await _deleteHousehold(hhId);
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                        ],

                                        if (!isOwner) ...[
                                          const SizedBox(height: 12),
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.exit_to_app, color: Colors.orange),
                                            label: const Text("Leave Household", style: TextStyle(color: Colors.orange)),
                                            onPressed: () async {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (_) => AlertDialog(
                                                  title: const Text("Leave Household"),
                                                  content: Text("Are you sure you want to leave $hhName?"),
                                                  actions: [
                                                    TextButton(
                                                      child: const Text("Cancel"),
                                                      onPressed: () => Navigator.pop(context, false),
                                                    ),
                                                    TextButton(
                                                      child: const Text("Leave", style: TextStyle(color: Colors.orange)),
                                                      onPressed: () => Navigator.pop(context, true),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (confirm == true) {
                                                await _leaveHousehold(hhId); // implement this in your service
                                                await _loadHouseholdsAndMembers();
                                              }
                                            },
                                          ),
                                        ],

                                        const SizedBox(height: 12),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _showCreateHouseholdDialog,
                              child: const Text("Create Household"),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade200,
                                foregroundColor: Colors.black,
                                elevation: 0,
                              ),
                              onPressed: _showJoinHouseholdDialog,
                              child: const Text("Join Household"),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
    );
  }
}
