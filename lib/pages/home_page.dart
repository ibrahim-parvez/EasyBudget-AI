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
// TODO: Import these pages once you create them
// import 'create_household_page.dart';
// import 'join_household_page.dart';
// import 'manage_households_page.dart';
// import 'manage_people_page.dart';

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

  @override
  void initState() {
    super.initState();
    _loadCurrentHousehold();
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


  void _handleMenuSelect(String value) {
    switch (value) {
      case 'manage_households':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const Placeholder(), // ManageHouseholdsPage()
          ),
        );
        break;
      case 'manage_people':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const Placeholder(), // ManagePeoplePage()
          ),
        );
        break;
      case 'settings':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SettingsPage(),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // No household view
    if (_householdId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Home'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.home_outlined, size: 64),
                const SizedBox(height: 12),
                const Text(
                  'No active household',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You can join an existing household or create a new one.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.group_add_rounded),
                  label: const Text('Join Household'),
                  // Join Household Button
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        String joinId = '';
                        String pinCode = '';

                        return AlertDialog(
                          title: const Text('Join Household'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                decoration: const InputDecoration(labelText: 'Join ID'),
                                onChanged: (value) => joinId = value.trim().toUpperCase(),
                              ),
                              TextField(
                                decoration: const InputDecoration(labelText: 'PIN Code'),
                                obscureText: true,
                                onChanged: (value) => pinCode = value.trim(),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                if (joinId.isEmpty || pinCode.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter both Join ID and PIN')),
                                  );
                                  return;
                                }

                                try {
                                  final query = await FirebaseFirestore.instance
                                      .collection('households')
                                      .where('joinId', isEqualTo: joinId)
                                      .where('pin', isEqualTo: pinCode)
                                      .limit(1)
                                      .get();

                                  if (query.docs.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('No household found with that Join ID and PIN')),
                                    );
                                  } else {
                                    final householdId = query.docs.first.id;
                                    final uid = FirebaseAuth.instance.currentUser!.uid;

                                    // Add user as member if not already
                                    await FirebaseFirestore.instance.collection('households').doc(householdId).update({
                                      'members': FieldValue.arrayUnion([uid]),
                                    });

                                    // Update user's currentHousehold field
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(uid)
                                        .update({'currentHousehold': householdId});

                                    // Update local state immediately to refresh UI
                                    setState(() {
                                      _householdId = householdId;
                                    });

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Joined household successfully')),
                                    );

                                    Navigator.pop(context);
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error joining household: $e')),
                                  );
                                }

                              },
                              child: const Text('Join'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_home_rounded),
                  label: const Text('Create Household'),
                  // Create Household Button
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        String householdName = '';
                        String pinCode = '';

                        return AlertDialog(
                          title: const Text('Create Household'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                decoration: const InputDecoration(labelText: 'Household Name'),
                                onChanged: (value) => householdName = value.trim(),
                              ),
                              TextField(
                                decoration: const InputDecoration(labelText: 'PIN Code'),
                                obscureText: true,
                                onChanged: (value) => pinCode = value.trim(),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                if (householdName.isEmpty || pinCode.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter both Household Name and PIN')),
                                  );
                                  return;
                                }

                                final joinId = generateJoinId();

                                final uid = FirebaseAuth.instance.currentUser!.uid;

                                // Create new household with joinId, pin, members includes creator
                                final householdRef = await FirebaseFirestore.instance
                                    .collection('households')
                                    .add({
                                  'name': householdName,
                                  'pin': pinCode,
                                  'joinId': joinId,
                                  'createdBy': uid,
                                  'members': [uid],
                                  'createdAt': FieldValue.serverTimestamp(),
                                });

                                // Set as user's current household
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(uid)
                                    .update({'currentHousehold': householdRef.id});
                                
                                setState(() {
                                  _householdId = householdRef.id;
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Household created! Join ID: $joinId')),
                                );

                                Navigator.pop(context);
                              },
                              child: const Text('Create'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Pages for when there is a household
    final pages = [
      _Dashboard(householdId: _householdId!),
      ExpensesPage(householdId: _householdId!),
      const SettingsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuSelect,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'manage_households',
                child: Text('Manage Households'),
              ),
              const PopupMenuItem(
                value: 'manage_people',
                child: Text('Manage People'),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Text('Settings'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(child: pages[idx]),
      bottomNavigationBar: FancyNavBar(
        currentIndex: idx,
        onTap: (i) => setState(() => idx = i),
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  final String householdId;
  const _Dashboard({super.key, required this.householdId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18.0),
      child: ListView(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Good morning,', style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 6),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('households')
                      .doc(householdId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Text('Loading...',
                          style: Theme.of(context).textTheme.titleLarge);
                    }
                    if (!snapshot.data!.exists) {
                      return Text('Household deleted',
                          style: Theme.of(context).textTheme.titleLarge);
                    }
                    final householdName =
                        (snapshot.data!.data() as Map<String, dynamic>)['name']
                            as String?;
                    return Text(
                      householdName ?? 'Household',
                      style: Theme.of(context).textTheme.titleLarge,
                    );
                  },
                ),
              ]),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.group_rounded),
              )
            ],
          ),
          const SizedBox(height: 18),

          RoundedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('This month'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 110,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(5, (i) {
                      final heights = [28.0, 52.0, 82.0, 64.0, 96.0];
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0),
                          child: Container(
                            height: heights[i],
                            decoration: BoxDecoration(
                              gradient: AppThemes.primaryGradient(
                                dark: Theme.of(context).brightness ==
                                    Brightness.dark,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('Spent: \$1,542'),
                    Text('Budget: \$2,500'),
                  ],
                )
              ],
            ),
          ),

          const SizedBox(height: 14),

          RoundedCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Recent activity'),
                SizedBox(height: 8),
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                      child: Icon(Icons.local_grocery_store_rounded)),
                  title: Text('Grocery'),
                  subtitle: Text('Aug 10'),
                  trailing: Text('- \$78'),
                ),
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading:
                      CircleAvatar(child: Icon(Icons.payments_rounded)),
                  title: Text('Electric bill'),
                  subtitle: Text('Aug 6'),
                  trailing: Text('- \$120'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
