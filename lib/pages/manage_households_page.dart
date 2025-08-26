import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  String generateJoinId([int length = 6]) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

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

  Future<void> _deleteHousehold(String householdId) async {
    await firestore.collection('households').doc(householdId).delete();
    await _loadHouseholdsAndMembers();
  }

  Future<void> _createHouseholdDialog() async {
    final nameController = TextEditingController();
    final pinController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Create Household"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Household Name"),
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
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final pin = pinController.text.trim();

              if (name.isEmpty || pin.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter both name and PIN")),
                );
                return;
              }

              final joinId = generateJoinId();

              await firestore.collection('households').add({
                'name': name,
                'pin': pin,
                'joinId': joinId,
                'createdBy': uid,
                'members': [uid],
                'createdAt': FieldValue.serverTimestamp(),
              });

              Navigator.pop(context);
              await _loadHouseholdsAndMembers();
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  Future<void> _joinHouseholdDialog() async {
    final joinIdController = TextEditingController();
    final pinController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
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
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
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

              final query = await firestore
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
              if (doc['pin'] != pin) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Incorrect PIN")),
                );
                return;
              }

              await doc.reference.update({
                'members': FieldValue.arrayUnion([uid]),
              });

              Navigator.pop(context);
              await _loadHouseholdsAndMembers();
            },
            child: const Text("Join"),
          ),
        ],
      ),
    );
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
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            isOwner
                                                ? GestureDetector(
                                                    onTap: () async {
                                                      final budgetController = TextEditingController(
                                                          text: (data['budget'] ?? '').toString());

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
                                                                        content: Text("Enter a valid number")),
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
                                                    child: Text(
                                                      "\$${(data['budget'] ?? 0).toStringAsFixed(2)}",
                                                      style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 16,
                                                          color: Colors.blue),
                                                    ),
                                                  )
                                                : Text(
                                                    "\$${(data['budget'] ?? 0).toStringAsFixed(2)}",
                                                    style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                        color: Colors.black),
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
                              onPressed: _createHouseholdDialog,
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
                              onPressed: _joinHouseholdDialog,
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
