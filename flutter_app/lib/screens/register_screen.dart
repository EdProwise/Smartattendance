import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Account fields
  final _loginIdCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  // School fields
  final _schoolNameCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _loginIdCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _schoolNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.register(
        loginId: _loginIdCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        schoolName: _schoolNameCtrl.text.trim(),
        schoolEmail: _emailCtrl.text.trim(),
      );
      if (mounted) context.go('/');
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
        title: const Text('Register School & Admin'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Register',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF854CF4)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Create a new school and its admin account',
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                      const SizedBox(height: 20),

                      if (_error != null) ...[
                        _ErrorBanner(message: _error!),
                        const SizedBox(height: 16),
                      ],

                      // ── School Details ──────────────────────────────────
                      _sectionLabel(Icons.school_outlined, 'School Details'),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF854CF4).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF854CF4).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF854CF4)),
                            const SizedBox(width: 6),
                            const Text(
                              'School code will be auto-generated',
                              style: TextStyle(fontSize: 12, color: Color(0xFF854CF4)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _schoolNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'School Name *',
                          prefixIcon: Icon(Icons.school_rounded),
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'School name is required' : null,
                      ),
                      const SizedBox(height: 24),

                      TextFormField(
                        controller: _loginIdCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Login ID *',
                          hintText: 'e.g. john_doe',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Login ID is required';
                          if (v.trim().length < 3) return 'At least 3 characters';
                          if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) {
                            return 'Letters, numbers and underscore only';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email *',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Email is required';
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePass,
                        decoration: InputDecoration(
                          labelText: 'Password *',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscurePass = !_obscurePass),
                          ),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) => AuthService.validatePassword(v ?? ''),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      _PasswordPolicyIndicator(password: _passwordCtrl.text),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _confirmCtrl,
                        obscureText: _obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password *',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _register(),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Please confirm your password';
                          if (v != _passwordCtrl.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _register,
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5, color: Colors.white),
                                )
                              : const Text('Register School & Create Admin'),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Already have an account? ',
                              style: TextStyle(color: Colors.black54)),
                          GestureDetector(
                            onTap: () => context.pop(),
                            child: const Text(
                              'Sign In',
                              style: TextStyle(
                                  color: Color(0xFF854CF4), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF854CF4)),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF854CF4),
            letterSpacing: 0.4,
          ),
        ),
      ],
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
                    Text(
                      r.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: r.met ? Colors.green : Colors.grey,
                      ),
                    ),
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
