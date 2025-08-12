import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  final _auth = AuthService();

  bool _isSignUp = false;
  bool _loading = false;
  bool _showEmailForm = false;

  late final AnimationController _animationController;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1), // start below view
      end: Offset.zero, // end at normal position
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _name.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleEmailForm() {
    setState(() {
      _showEmailForm = !_showEmailForm;
      if (_showEmailForm) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _toggleMode() => setState(() => _isSignUp = !_isSignUp);

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      if (_isSignUp) {
        await _auth.signUpWithEmail(_name.text.trim(), _email.text.trim(), _pass.text.trim());
        // Navigate to onboarding after sign up
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/onboarding');
      } else {
        await _auth.signInWithEmail(_email.text.trim(), _pass.text.trim());
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      await _auth.signInWithGoogle();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google sign in failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _appleSignIn() async {
    // Implement your Apple sign-in logic here
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Apple Sign-In not implemented')));
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final logoAsset = brightness == Brightness.dark
        ? 'assets/images/logo_no_background_dark.png'
        : 'assets/images/logo_no_background_light.png';

    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: screenHeight * 0.4, // 30% height for logo
              child: Center(
                child: Image.asset(logoAsset, fit: BoxFit.contain),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  // Default sign-in options
                  AnimatedOpacity(
                    opacity: _showEmailForm ? 0 : 1,
                    duration: const Duration(milliseconds: 300),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.login),
                            label: const Text('Sign in with Google'),
                            onPressed: _loading ? null : _googleSignIn,
                            style: ElevatedButton.styleFrom(minimumSize: const Size(280, 50)),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.apple),
                            label: const Text('Sign in with Apple'),
                            onPressed: _loading ? null : _appleSignIn,
                            style: ElevatedButton.styleFrom(minimumSize: const Size(280, 50)),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _toggleEmailForm,
                            child: const Text('Sign in with Email'),
                            style: ElevatedButton.styleFrom(minimumSize: const Size(280, 50)),
                          ),
                        ],
                      ),
                    ),
                  ), 

                  // Sliding email form
                  SlideTransition(
                    position: _slideAnimation,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, -5),
                            ),
                          ],
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _isSignUp ? 'Create Account' : 'Sign In',
                                      style: Theme.of(context).textTheme.headlineSmall,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: _toggleEmailForm,
                                  )
                                ],
                              ),
                              if (_isSignUp)
                                TextField(
                                  controller: _name,
                                  decoration: const InputDecoration(labelText: 'Name'),
                                ),
                              TextField(
                                controller: _email,
                                decoration: const InputDecoration(labelText: 'Email'),
                                keyboardType: TextInputType.emailAddress,
                              ),
                              TextField(
                                controller: _pass,
                                decoration: const InputDecoration(labelText: 'Password'),
                                obscureText: true,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loading ? null : _submit,
                                child: Text(_isSignUp ? 'Create Account' : 'Sign In'),
                                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                              ),
                              TextButton(
                                onPressed: _loading ? null : _toggleMode,
                                child: Text(_isSignUp
                                    ? 'Already have an account? Sign In'
                                    : 'Don\'t have an account? Create one'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
