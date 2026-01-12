import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../shell/app_shell.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _usernameCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showPassword = false;
  bool _showConfirm = false;
  bool _agree = false;

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final r = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return r.hasMatch(email);
  }

  bool _isValidUsername(String username) {
    // Simple rule: 3-24 chars, letters/numbers/._ only
    final r = RegExp(r'^[a-zA-Z0-9._]{3,24}$');
    return r.hasMatch(username);
  }

  Future<void> _registerAndGoToBudgetSettings() async {
    final username = _usernameCtrl.text.trim();
    final fullName = _fullNameCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if (username.isEmpty ||
        fullName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirm.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }

    if (!_isValidUsername(username)) {
      setState(() => _error =
          'Username must be 3–24 chars and contain only letters, numbers, "." or "_".');
      return;
    }

    if (!_isValidEmail(email)) {
      setState(() => _error = 'Please enter a valid email.');
      return;
    }

    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }

    if (password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    if (!_agree) {
      setState(() => _error = 'Please agree to the Terms and Privacy Policy.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) Register user
      await AuthService.register(
        username: username,
        fullName: fullName,
        email: email,
        password: password,
      );

      // 2) Auto-login so JWT tokens are saved and future API calls work
      await AuthService.login(username: username, password: password);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created! Set your budgets to continue.'),
        ),
      );

      // 3) Go straight to budget settings (wipe stack)
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/budget-settings',
        (route) => false,
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AppShell(
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEFF6FF), Color(0xFFE0E7FF)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      children: [
                        const _HeaderSection(),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              32,
                              8,
                              32,
                              28 + bottomInset,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ✅ USERNAME FIELD
                                const _Label('Username'),
                                const SizedBox(height: 8),
                                _TextFieldPill(
                                  controller: _usernameCtrl,
                                  hint: 'Choose a username',
                                  keyboardType: TextInputType.text,
                                  obscureText: false,
                                ),
                                const SizedBox(height: 16),

                                const _Label('Full Name'),
                                const SizedBox(height: 8),
                                _TextFieldPill(
                                  controller: _fullNameCtrl,
                                  hint: 'Enter your full name',
                                  keyboardType: TextInputType.name,
                                  obscureText: false,
                                ),
                                const SizedBox(height: 16),

                                const _Label('Email'),
                                const SizedBox(height: 8),
                                _TextFieldPill(
                                  controller: _emailCtrl,
                                  hint: 'Enter your email',
                                  keyboardType: TextInputType.emailAddress,
                                  obscureText: false,
                                ),
                                const SizedBox(height: 16),

                                const _Label('Password'),
                                const SizedBox(height: 8),
                                _PasswordFieldPill(
                                  controller: _passCtrl,
                                  hint: 'Create a password',
                                  obscureText: !_showPassword,
                                  isShowing: _showPassword,
                                  onToggle: () => setState(
                                    () => _showPassword = !_showPassword,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Must be at least 8 characters',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                const _Label('Confirm Password'),
                                const SizedBox(height: 8),
                                _PasswordFieldPill(
                                  controller: _confirmCtrl,
                                  hint: 'Confirm your password',
                                  obscureText: !_showConfirm,
                                  isShowing: _showConfirm,
                                  onToggle: () => setState(
                                    () => _showConfirm = !_showConfirm,
                                  ),
                                ),

                                const SizedBox(height: 14),

                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: Checkbox(
                                          value: _agree,
                                          onChanged: _loading
                                              ? null
                                              : (v) => setState(
                                                    () => _agree = v ?? false,
                                                  ),
                                          activeColor:
                                              const Color(0xFF3B82F6),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Wrap(
                                        children: [
                                          const Text(
                                            'I agree to the ',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF4B5563),
                                              height: 1.35,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () {},
                                            child: const Text(
                                              'Terms of Service',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF3B82F6),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const Text(
                                            ' and ',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF4B5563),
                                              height: 1.35,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () {},
                                            child: const Text(
                                              'Privacy Policy',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF3B82F6),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                if (_error != null) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xFFFCA5A5),
                                      ),
                                    ),
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: Color(0xFF991B1B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 18),

                                _GradientButton(
                                  text: _loading
                                      ? 'Creating...'
                                      : 'Create Account',
                                  enabled: !_loading,
                                  onTap: _registerAndGoToBudgetSettings,
                                ),

                                const SizedBox(height: 18),
                                const _DividerLabel(label: 'or sign up with'),
                                const SizedBox(height: 14),

                                Row(
                                  children: [
                                    Expanded(
                                      child: _SocialButton(
                                        label: 'Google',
                                        icon: const _GoogleIcon(size: 18),
                                        enabled: !_loading,
                                        onTap: () {},
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _SocialButton(
                                        label: 'Apple',
                                        icon: const _AppleIcon(size: 18),
                                        enabled: !_loading,
                                        onTap: () {},
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 18),
                                Center(
                                  child: Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      const Text(
                                        'Already have an account? ',
                                        style: TextStyle(
                                          color: Color(0xFF4B5563),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: _loading
                                            ? null
                                            : () => Navigator.of(context)
                                                .pushNamedAndRemoveUntil(
                                                    '/login', (route) => false),
                                        child: const Text(
                                          'Sign In',
                                          style: TextStyle(
                                            color: Color(0xFF3B82F6),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
        ),
      ),
    );
  }
}

/// ---------------- Header ----------------

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _BrandLogo(),
          SizedBox(height: 16),
          Text(
            'Create Account',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
              height: 1.15,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Sign up to start managing your finances',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF4F46E5)],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 10)),
        ],
      ),
      alignment: Alignment.center,
      child: const Text('💰', style: TextStyle(fontSize: 30)),
    );
  }
}

/// ---------------- Shared Widgets ----------------

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF374151),
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }
}

class _TextFieldPill extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final bool obscureText;

  const _TextFieldPill({
    required this.controller,
    required this.hint,
    required this.keyboardType,
    required this.obscureText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        ),
      ),
    );
  }
}

class _PasswordFieldPill extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final VoidCallback onToggle;
  final bool isShowing;

  const _PasswordFieldPill({
    required this.controller,
    required this.hint,
    required this.obscureText,
    required this.onToggle,
    required this.isShowing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onToggle,
            child: Icon(
              isShowing ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: const Color(0xFF9CA3AF),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String text;
  final bool enabled;
  final VoidCallback onTap;

  const _GradientButton({
    required this.text,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.65,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF3B82F6), Color(0xFF4F46E5)],
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 10)),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
      ),
    );
  }
}

class _DividerLabel extends StatelessWidget {
  final String label;
  const _DividerLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE5E7EB), thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        ),
        const Expanded(child: Divider(color: Color(0xFFE5E7EB), thickness: 1)),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final bool enabled;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.65,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            color: Colors.white,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  final double size;
  const _GoogleIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4285F4)),
      alignment: Alignment.center,
      child: Container(
        width: size * 0.42,
        height: size * 0.42,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
      ),
    );
  }
}

class _AppleIcon extends StatelessWidget {
  final double size;
  const _AppleIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.apple, size: size + 2, color: Colors.black);
  }
}
