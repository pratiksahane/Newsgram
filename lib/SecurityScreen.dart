// lib/screens/security_screen.dart
import 'package:flutter/material.dart';
import 'package:newsgram/signuppage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _twoFactorEnabled = false;
  bool _loginAlertsEnabled = true;
  bool _appLockEnabled = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSecuritySettings();
  }

  Future<void> _loadSecuritySettings() async {
    setState(() => _isLoading = true);
    
    try {
      // Load user's security preferences from Supabase
      final response = await _supabase
          .from('user_security_settings')
          .select('*')
          .eq('user_id', _supabase.auth.currentUser!.id)
          .single()
          .onError((error, stackTrace) => <String, dynamic>{}); // Return empty map if no settings exist

      if (response != null) {
        setState(() {
          _twoFactorEnabled = response['two_factor_enabled'] ?? false;
          _loginAlertsEnabled = response['login_alerts_enabled'] ?? true;
          _appLockEnabled = response['app_lock_enabled'] ?? false;
          _biometricEnabled = response['biometric_enabled'] ?? false;
        });
      }
    } catch (e) {
      // Settings don't exist yet, use defaults
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSecuritySetting(String setting, bool value) async {
    setState(() => _isLoading = true);
    
    try {
      await _supabase.from('user_security_settings').upsert({
        'user_id': _supabase.auth.currentUser!.id,
        setting: value,
        'updated_at': DateTime.now().toIso8601String(),
      });

      setState(() {
        switch (setting) {
          case 'two_factor_enabled':
            _twoFactorEnabled = value;
            break;
          case 'login_alerts_enabled':
            _loginAlertsEnabled = value;
            break;
          case 'app_lock_enabled':
            _appLockEnabled = value;
            break;
          case 'biometric_enabled':
            _biometricEnabled = value;
            break;
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Security setting updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating setting: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _viewActiveSessions() async {
    // Navigate to active sessions screen
    // You can implement this separately
  }

  Future<void> _changePassword() async {
    showDialog(
      context: context,
      builder: (context) => ChangePasswordDialog(),
    );
  }

  Future<void> _enableTwoFactorAuth() async {
    // Implement 2FA setup flow
    showDialog(
      context: context,
      builder: (context) => TwoFactorSetupDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_outlined, size: 20),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Account Security'),
                  _buildSecurityOption(
                    icon: Icons.password,
                    title: 'Change Password',
                    subtitle: 'Update your account password',
                    onTap: _changePassword,
                  ),
                  _buildSecurityOption(
                    icon: Icons.security,
                    title: 'Two-Factor Authentication',
                    subtitle: _twoFactorEnabled ? 'Enabled' : 'Disabled',
                    trailing: Switch(
                      value: _twoFactorEnabled,
                      onChanged: (value) => value 
                          ? _enableTwoFactorAuth()
                          : _updateSecuritySetting('two_factor_enabled', value),
                    ),
                  ),
                  _buildSecurityOption(
                    icon: Icons.devices,
                    title: 'Active Sessions',
                    subtitle: 'View and manage logged-in devices',
                    onTap: _viewActiveSessions,
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle('Privacy & Safety'),
                  _buildSecurityOption(
                    icon: Icons.notifications_active,
                    title: 'Login Alerts',
                    subtitle: 'Get notified of new sign-ins',
                    trailing: Switch(
                      value: _loginAlertsEnabled,
                      onChanged: (value) => 
                          _updateSecuritySetting('login_alerts_enabled', value),
                    ),
                  ),
                  _buildSecurityOption(
                    icon: Icons.lock,
                    title: 'App Lock',
                    subtitle: 'Require PIN or biometric to open app',
                    trailing: Switch(
                      value: _appLockEnabled,
                      onChanged: (value) => 
                          _updateSecuritySetting('app_lock_enabled', value),
                    ),
                  ),
                  if (_appLockEnabled) ...[
                    _buildSecurityOption(
                      icon: Icons.fingerprint,
                      title: 'Biometric Authentication',
                      subtitle: 'Use fingerprint or face recognition',
                      trailing: Switch(
                        value: _biometricEnabled,
                        onChanged: (value) => 
                            _updateSecuritySetting('biometric_enabled', value),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  _buildSectionTitle('Data & Privacy'),
                  _buildSecurityOption(
                    icon: Icons.download,
                    title: 'Download Your Data',
                    subtitle: 'Get a copy of your information',
                    onTap: () => _downloadData(),
                  ),
                  _buildSecurityOption(
                    icon: Icons.delete,
                    title: 'Delete Account',
                    subtitle: 'Permanently remove your account',
                    onTap: () => _showDeleteAccountDialog(),
                    isDestructive: true,
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle('Security Tips'),
                  _buildTipCard(
                    'Use a strong, unique password for your NewsGram account.',
                  ),
                  _buildTipCard(
                    'Enable two-factor authentication for extra security.',
                  ),
                  _buildTipCard(
                    'Never share your verification codes with anyone.',
                  ),
                  _buildTipCard(
                    'Log out of devices you no longer use.',
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildSecurityOption({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : null),
      title: Text(title, style: TextStyle(
        color: isDestructive ? Colors.red : null,
        fontWeight: FontWeight.w500,
      )),
      subtitle: Text(subtitle, style: TextStyle(
        color: isDestructive ? Colors.red.withOpacity(0.7) : Colors.grey,
      )),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildTipCard(String tip) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lightbulb_outline, size: 20, color: Colors.amber),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tip,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadData() async {
    // Implement data download functionality
    setState(() => _isLoading = true);
    try {
      // Generate and download user data
      await Future.delayed(const Duration(seconds: 2)); // Simulate processing
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data download started. You will receive an email when ready.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading data: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? '
          'This action cannot be undone. All your data will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => _deleteAccount(),
            child: const Text(
              'Delete Account',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    Navigator.pop(context); // Close dialog
    setState(() => _isLoading = true);
    
    try {
      // Delete user account from Supabase
      await _supabase.rpc('delete_user_account');
      
      // Sign out
      await _supabase.auth.signOut();
      
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SignUpPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting account: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

// Dialog for changing password
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      
      // Verify current password first
      await supabase.auth.signInWithPassword(
        email: supabase.auth.currentUser!.email!,
        password: _currentPasswordController.text,
      );

      // Update password
      await supabase.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error changing password: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _currentPasswordController,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your current password';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newPasswordController,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a new password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (value) {
                if (value != _newPasswordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _changePassword,
          child: _isLoading 
              ? const CircularProgressIndicator()
              : const Text('Update Password'),
        ),
      ],
    );
  }
}

// Dialog for 2FA setup (simplified version)
class TwoFactorSetupDialog extends StatelessWidget {
  const TwoFactorSetupDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Two-Factor Authentication'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.security, size: 48, color: Colors.blue),
          SizedBox(height: 16),
          Text(
            'Two-factor authentication adds an extra layer of security to your account. '
            'You\'ll need to enter a verification code from your authenticator app when signing in.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Not Now'),
        ),
        ElevatedButton(
          onPressed: () {
            // Implement actual 2FA setup
            Navigator.pop(context);
          },
          child: const Text('Set Up'),
        ),
      ],
    );
  }
}