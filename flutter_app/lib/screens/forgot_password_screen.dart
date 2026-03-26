import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Step 1: enter email  |  Step 2: enter code + new password
  int _step = 1;

  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;
  String? _successCode; // shown in dev/demo mode
  String _email = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_step1Key.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      _email = _emailCtrl.text.trim();
      final code = await AuthService.forgotPassword(_email);
      setState(() {
        _step = 2;
        _successCode = code.isNotEmpty ? code : null;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Could not connect to server'; _loading = false; });
    }
  }

  Future<void> _resetPassword() async {
    if (!_step2Key.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.resetPassword(
        email: _email,
        resetCode: _codeCtrl.text.trim(),
        newPassword: _newPassCtrl.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset successfully! Please sign in.'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/login');
      }
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Could not connect to server'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FF),
      appBar: AppBar(
        title: const Text('Forgot Password'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _step == 1 ? _buildStep1() : _buildStep2(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Form(
      key: _step1Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            const Icon(Icons.lock_reset_rounded, size: 52, color: Color(0xFF854CF4)),
          const SizedBox(height: 16),
          const Text(
            'Reset Password',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Enter the email address linked to your account and we\'ll send you a reset code.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 24),

          if (_error != null) ...[
            _ErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],

          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _sendCode(),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _sendCode,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Send Reset Code'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Form(
      key: _step2Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.verified_user_rounded, size: 52, color: Colors.green),
          const SizedBox(height: 16),
          const Text(
            'Enter Reset Code',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'A reset code was generated for $_email',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 8),

          // Dev/demo: show the code directly
          if (_successCode != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Your reset code: ',
                    style: TextStyle(color: Colors.blue.shade800, fontSize: 13),
                  ),
                  Text(
                    _successCode!,
                    style: TextStyle(
                      color: Colors.blue.shade800,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          if (_error != null) ...[
            _ErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],

          // Reset code
          TextFormField(
            controller: _codeCtrl,
            decoration: const InputDecoration(
              labelText: 'Reset Code',
              prefixIcon: Icon(Icons.pin_outlined),
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.characters,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Reset code is required' : null,
          ),
          const SizedBox(height: 14),

          // New password
          TextFormField(
            controller: _newPassCtrl,
            obscureText: _obscureNew,
            decoration: InputDecoration(
              labelText: 'New Password',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            validator: (v) => AuthService.validatePassword(v ?? ''),
          ),
          const SizedBox(height: 8),
          _PasswordPolicyIndicator(password: _newPassCtrl.text),
          const SizedBox(height: 14),

          // Confirm password
          TextFormField(
            controller: _confirmPassCtrl,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: 'Confirm New Password',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _resetPassword(),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm your password';
              if (v != _newPassCtrl.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _resetPassword,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Reset Password'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() { _step = 1; _error = null; }),
            child: const Text('Use a different email'),
          ),
        ],
      ),
    );
  }
}

class _PasswordPolicyIndicator extends StatelessWidget {
  final String password;
  const _PasswordPolicyIndicator({required this.password});

  @override
  Widget build(BuildContext context) {
    final rules = [
      _PolicyRule('At least 8 characters', password.length >= 8),
      _PolicyRule('1 uppercase letter (A-Z)', password.contains(RegExp(r'[A-Z]'))),
      _PolicyRule('1 number (0-9)', password.contains(RegExp(r'\d'))),
      _PolicyRule('1 symbol (!@#...)',
            password.contains(RegExp(r'[!@#$%^&*()\-_=+\[\]{};:,./<>?\\|]'))),
    ];
    return Column(
      children: rules
          .map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      r.met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                      size: 15,
                      color: r.met ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(r.label,
                        style: TextStyle(
                            fontSize: 12, color: r.met ? Colors.green : Colors.grey)),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _PolicyRule {
  final String label;
  final bool met;
  const _PolicyRule(this.label, this.met);
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
