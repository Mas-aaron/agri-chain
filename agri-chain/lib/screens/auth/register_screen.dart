import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agri_chain/services/auth_service.dart';
import 'package:agri_chain/providers/verifier_provider.dart';
import 'package:agri_chain/screens/verifier/verifier_dashboard.dart';
import 'package:agri_chain/features/logistics/providers/logistics_provider.dart';
import 'package:agri_chain/features/logistics/screens/job_board_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final _confirmCtl = TextEditingController();
  final _orgNameCtl = TextEditingController();
  final _companyNameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String _selectedRole = 'Farmer';

  static const _roles = ['Farmer', 'Verifier', 'Logistics Company'];

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final email = _emailCtl.text.trim();
      final pass = _passCtl.text.trim();
      final confirm = _confirmCtl.text.trim();
      
      if (email.isEmpty || pass.isEmpty) {
        throw Exception('Please enter email and password.');
      }
      
      if (pass != confirm) {
        throw Exception('Passwords do not match.');
      }

      if (_selectedRole == 'Verifier' && _orgNameCtl.text.trim().isEmpty) {
        throw Exception('Organization name is required for verifiers.');
      }

      if (_selectedRole == 'Logistics Company' && _companyNameCtl.text.trim().isEmpty) {
        throw Exception('Company name is required for logistics accounts.');
      }

      await context.read<AuthService>().registerWithEmail(email, pass);

      if (_selectedRole == 'Verifier') {
        // Register as verifier using the real Firebase UID so _RoleRouter
        // can find this record on subsequent logins.
        if (!mounted) return;
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) throw Exception('Authentication failed. Please try again.');
        final verifierProv = context.read<VerifierProvider>();
        await verifierProv.register(
          userId: uid,
          organizationName: _orgNameCtl.text.trim(),
          organizationType: 'INSPECTOR',
        );
        await verifierProv.loadDashboardData();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const VerifierDashboard()),
          );
        }
      } else if (_selectedRole == 'Logistics Company') {
        // Save logistics role locally so AuthWrapper can route correctly on next login
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_role_$email', 'logistics');
        await prefs.setString('logistics_company_$email', _companyNameCtl.text.trim());
        if (_phoneCtl.text.trim().isNotEmpty) {
          await prefs.setString('logistics_phone_$email', _phoneCtl.text.trim());
        }
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const JobBoardScreen()),
        );
      } else {
        // Default farmer flow — pop and let AuthWrapper redirect
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) Navigator.pop(context);
      }
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
      appBar: AppBar(title: const Text('Create Account'), elevation: 0),
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
                    Text('Join AgriChain', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    const Text('Register to access advanced farming and verification tools.'),
                    const SizedBox(height: 32),
                    
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

                    // ── Role selector ───────────────────────────
                    DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: InputDecoration(
                        labelText: 'I am a...',
                        prefixIcon: Icon(
                          _selectedRole == 'Verifier'
                              ? Icons.verified_user
                              : _selectedRole == 'Logistics Company'
                                  ? Icons.local_shipping
                                  : Icons.agriculture,
                          color: _selectedRole == 'Verifier'
                              ? Colors.deepPurple
                              : _selectedRole == 'Logistics Company'
                                  ? Colors.orange.shade700
                                  : scheme.primary,
                        ),
                      ),
                      items: _roles
                          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedRole = v!),
                    ),
                    const SizedBox(height: 16),

                    // ── Verifier-specific: org name ─────────────
                    if (_selectedRole == 'Verifier') ...[
                      TextField(
                        controller: _orgNameCtl,
                        decoration: const InputDecoration(
                          labelText: 'Organization Name',
                          prefixIcon: Icon(Icons.business),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Logistics-specific fields ────────────────
                    if (_selectedRole == 'Logistics Company') ...[
                      TextField(
                        controller: _companyNameCtl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Company Name *',
                          hintText: 'e.g. Kampala Freight Ltd',
                          prefixIcon: Icon(Icons.business_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _phoneCtl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Contact Phone (optional)',
                          hintText: '+256 700 000 000',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                      
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
                    const SizedBox(height: 16),
                    TextField(
                      controller: _confirmCtl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Confirm Password', prefixIcon: Icon(Icons.lock_reset)),
                    ),
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _register,
                        style: _selectedRole == 'Verifier'
                            ? FilledButton.styleFrom(backgroundColor: Colors.deepPurple)
                            : _selectedRole == 'Logistics Company'
                                ? FilledButton.styleFrom(backgroundColor: Colors.orange.shade700)
                                : null,
                        child: _isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(_selectedRole == 'Verifier'
                                ? 'Create Verifier Account'
                                : _selectedRole == 'Logistics Company'
                                    ? 'Create Logistics Account'
                                    : 'Create Account'),
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

