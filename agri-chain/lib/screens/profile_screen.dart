import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _keyName = 'agri_profile_name';
  static const _keyPhone = 'agri_profile_phone';
  static const _keyLocation = 'agri_profile_location';
  static const _keyFarmSize = 'agri_profile_farm_size';

  final _nameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _locationCtl = TextEditingController();
  final _farmSizeCtl = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;

    _nameCtl.text = prefs.getString(_keyName) ?? user?.displayName ?? '';
    _phoneCtl.text = prefs.getString(_keyPhone) ?? '';
    _locationCtl.text = prefs.getString(_keyLocation) ?? '';
    _farmSizeCtl.text = prefs.getString(_keyFarmSize) ?? '';

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, _nameCtl.text.trim());
    await prefs.setString(_keyPhone, _phoneCtl.text.trim());
    await prefs.setString(_keyLocation, _locationCtl.text.trim());
    await prefs.setString(_keyFarmSize, _farmSizeCtl.text.trim());

    // Update Firebase display name if changed
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _nameCtl.text.trim().isNotEmpty) {
      try {
        await user.updateDisplayName(_nameCtl.text.trim());
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile saved ✓'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _locationCtl.dispose();
    _farmSizeCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Avatar + email header
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: scheme.primaryContainer,
                        child: Text(
                          (_nameCtl.text.isNotEmpty ? _nameCtl.text[0] : '?').toUpperCase(),
                          style: TextStyle(fontSize: 32, color: scheme.onPrimaryContainer, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        user?.email ?? 'No email',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      Text(
                        'UID: ${(user?.uid ?? '').substring(0, (user?.uid.length ?? 0) > 8 ? 8 : (user?.uid.length ?? 0))}…',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant.withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Editable fields
                _buildField(
                  controller: _nameCtl,
                  label: 'Display Name',
                  icon: Icons.person_outlined,
                  hint: 'e.g. John Mwangi',
                ),
                const SizedBox(height: 14),
                _buildField(
                  controller: _phoneCtl,
                  label: 'Phone Number',
                  icon: Icons.phone_outlined,
                  hint: '+256 700 123 456',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                _buildField(
                  controller: _locationCtl,
                  label: 'Farm Location',
                  icon: Icons.location_on_outlined,
                  hint: 'e.g. Lira, Northern Uganda',
                ),
                const SizedBox(height: 14),
                _buildField(
                  controller: _farmSizeCtl,
                  label: 'Farm Size (hectares)',
                  icon: Icons.straighten_outlined,
                  hint: 'e.g. 2.5',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),

                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveProfile,
                  icon: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? 'Saving…' : 'Save Profile'),
                ),
              ],
            ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }
}
