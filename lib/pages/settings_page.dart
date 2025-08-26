import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/rounded_card.dart';
import '../theme/theme_provider.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AuthService _authService = AuthService();
  bool _notificationsEnabled = true;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    if (doc.exists) {
      setState(() {
        _userName = doc.data()?['name'] ?? "Unnamed User";
      });
    }
  }

  Future<void> _handleLogout() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final tp = Provider.of<ThemeProvider>(context);
    final isDark = tp.mode == ThemeMode.dark ||
        (tp.mode == ThemeMode.system &&
            Theme.of(context).brightness == Brightness.dark);
    final cardColor = isDark ? Colors.grey[900] : Colors.white;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Section
          RoundedCard(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.blueGrey,
                child: const Icon(Icons.person, size: 32, color: Colors.white),
              ),
              title: Text(_userName ?? "Loading...", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Edit profile & personal details"),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EditProfilePage(),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          // App Settings Section
          RoundedCard(
            child: Column(
              children: [
                ListTile(
                  title: const Text("Appearance"),
                  subtitle: const Text("Light / Dark mode"),
                  trailing: Switch(
                    value: isDark,
                    onChanged: (v) => tp.toggleTheme(),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text("Notifications"),
                  subtitle: const Text("Enable or disable push notifications"),
                  trailing: Switch(
                    value: _notificationsEnabled,
                    onChanged: (v) {
                      setState(() => _notificationsEnabled = v);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Info Section
          RoundedCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text("About EasyBudget AI"),
                  subtitle: const Text("Version 0.1"),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help_outline_rounded),
                  title: const Text("Help & Feedback"),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: const Text("Legal"),
                  onTap: () {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Logout Section
          RoundedCard(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                "Logout",
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              onTap: _handleLogout,
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// --------------------- EDIT PROFILE PAGE ----------------------

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  String? _selectedCurrency;

  bool _loading = true;
  bool _isEmailPasswordUser = false;

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
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      _nameController.text = data['name'] ?? '';
      _selectedCurrency = data['currency'] ?? 'USD';
    }

    _isEmailPasswordUser =
        user.providerData.any((p) => p.providerId == 'password');

    setState(() => _loading = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'name': _nameController.text.trim(),
      'currency': _selectedCurrency,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully')),
    );
    Navigator.pop(context);
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Change Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: "Current Password"),
            ),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "New Password"),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;

              final cred = EmailAuthProvider.credential(
                email: user.email!,
                password: currentPasswordController.text.trim(),
              );

              try {
                await user.reauthenticateWithCredential(cred);
                await user.updatePassword(newPasswordController.text.trim());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Password updated successfully")),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e")),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Change"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
            "Are you sure you want to permanently delete your account? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
      await user.delete();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting account: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profile")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              const SizedBox(height: 10),

              // Currency dropdown with flags
              DropdownButtonFormField<String>(
                value: _currencyList.any((c) => c['code'] == _selectedCurrency)
                    ? _selectedCurrency
                    : null,
                decoration: const InputDecoration(labelText: "Preferred Currency"),
                items: _currencyList.map((c) {
                  return DropdownMenuItem<String>(
                    value: c['code'],
                    child: Row(
                      children: [
                        Text(_flagEmoji(c['countryCode']!)),
                        const SizedBox(width: 8),
                        Text("${c['name']} (${c['code']})"),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCurrency = val),
              ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _saveProfile,
                child: const Text("Save Changes"),
              ),
              const SizedBox(height: 20),

              if (_isEmailPasswordUser)
                OutlinedButton(
                  onPressed: _showChangePasswordDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: const Text("Change Password"),
                ),

              const SizedBox(height: 20),

              OutlinedButton(
                onPressed: _deleteAccount,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                child: const Text("Delete Account"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _flagEmoji(String countryCode) {
    return countryCode.toUpperCase().codeUnits
        .map((c) => String.fromCharCode(c + 127397))
        .join();
  }
}