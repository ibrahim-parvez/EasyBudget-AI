import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../widgets/rounded_card.dart';
import '../theme/theme_provider.dart';     // ThemeProvider class
import '../services/auth_service.dart';   // AuthService for logout

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AuthService _authService = AuthService();

  Future<void> _handleLogout() async {
    await _authService.signOut();

    if (!mounted) return; // check if widget is still mounted before navigating

    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final tp = Provider.of<ThemeProvider>(context);
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: ListView(
          children: [
            RoundedCard(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Appearance'),
                    subtitle: const Text('Light / Dark mode'),
                    trailing: Switch(
                      value: tp.mode == ThemeMode.dark,
                      onChanged: (v) => tp.toggleTheme(),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.lock_rounded),
                    title: const Text('Change PIN'),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const Icon(Icons.people_rounded),
                    title: const Text('Manage household'),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            RoundedCard(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text('About EasyBudget AI'),
                    subtitle: const Text('Version 0.1'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.help_outline_rounded),
                    title: const Text('Help & Feedback'),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            RoundedCard(
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: _handleLogout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}