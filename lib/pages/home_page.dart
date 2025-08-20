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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // No household view
    if (_householdId == null) {
      return _noHouseholdView(context);
    }

    // Pages for when there is a household
    final pages = [
      _Dashboard(householdId: _householdId!),
      ExpensesPage(householdId: _householdId!),
      const SettingsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('households')
              .doc(_householdId)
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
        ),
      ),
      body: SafeArea(child: pages[idx]),
      bottomNavigationBar: FancyNavBar(
        currentIndex: idx,
        onTap: (i) => setState(() => idx = i),
      ),
    );
  }

  /// Household dropdown as a modal bottom sheet
  void _showHouseholdSelector(BuildContext context) {
    showModalBottomSheet(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Switch Household",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            ..._userHouseholds.map((h) => ListTile(
                  title: Text(h['name']),
                  onTap: () async {
                    final uid = FirebaseAuth.instance.currentUser!.uid;
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
      ),
    );
  }

  /// Create Household Dialog
  void _showCreateHouseholdDialog(BuildContext context) {
    String householdName = '';
    String pinCode = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Household'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Household Name'),
              onChanged: (v) => householdName = v.trim(),
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'PIN Code'),
              obscureText: true,
              onChanged: (v) => pinCode = v.trim(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            child: const Text("Create"),
            onPressed: () async {
              if (householdName.isEmpty || pinCode.isEmpty) return;
              final joinId = generateJoinId();
              final uid = FirebaseAuth.instance.currentUser!.uid;

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

              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .update({'currentHousehold': householdRef.id});

              setState(() => _householdId = householdRef.id);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  /// No Household screen
  Widget _noHouseholdView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const Center(child: Text("No active household")),
    );
  }
}

class _Dashboard extends StatelessWidget {
  final String householdId;
  const _Dashboard({super.key, required this.householdId});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Padding(
      padding: const EdgeInsets.all(18.0),
      child: ListView(
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
                      .doc(householdId)
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
                        children: members
                            .map((m) => ListTile(title: Text(m)))
                            .toList(),
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
