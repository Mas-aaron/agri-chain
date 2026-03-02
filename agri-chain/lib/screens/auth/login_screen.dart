import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:agri_chain/services/auth_service.dart';
import 'package:agri_chain/home_screen.dart';
import 'package:agri_chain/screens/auth/register_screen.dart';
import 'package:agri_chain/widgets/modern_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _login() async {
    // Check Firebase is initialized before attempting sign-in
    if (Firebase.apps.isEmpty) {
      setState(() => _error =
          'Authentication is not available on this platform.\n'
          'Please use the Android app to sign in, or tap "Continue as Guest" below.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final email = _emailCtl.text.trim();
      final pass = _passCtl.text.trim();
      
      if (email.isEmpty || pass.isEmpty) {
        throw Exception('Please enter email and password.');
      }

      await context.read<AuthService>().signInWithEmail(email, pass);
      // AuthWrapper will automatically react to the state change and route to AppShell
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll(RegExp(r'\[.*\]'), '').trim();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 4,
              shadowColor: Colors.black12,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.spa_rounded, size: 48, color: scheme.primary),
                    ),
                    const SizedBox(height: 16),
                    Text('AgriChain', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: scheme.primary)),
                    const SizedBox(height: 8),
                    const Text('Sign in to manage your fields, view alerts, and access traceability.', textAlign: TextAlign.center),
                    const SizedBox(height: 32),
                    
                    // Web notice: show when Firebase is not available
                    if (kIsWeb && Firebase.apps.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Web demo mode — sign-in requires the Android app. '  
                                'Use "Continue as Guest" to explore features.',
                                style: TextStyle(color: Colors.blue.shade800, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(_error!, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
                      ),
                      
                    TextField(
                      controller: _emailCtl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passCtl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                    ),
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _login,
                        child: _isLoading 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                            : const Text('Login'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                      },
                      child: const Text('New farmer? Create an account'),
                    ),
                    
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(),
                    ),
                    
                    Text('Need to quickly scan a leaf offline?', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        // Embedded mode tells HomeScreen to not show the AppShell bottom navigation if it's running standalone
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeScreen(embedded: false))),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Continue as Guest Scanner'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
