import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../shell/app_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _showPassword = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final username = _usernameCtrl.text.trim();
    final password = _passCtrl.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter username and password.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService.login(username: username, password: password);

      if (!mounted) return;

      // ✅ Go to main app area (budget wheel), wipe stack
      Navigator.of(context).pushNamedAndRemoveUntil('/budget', (route) => false);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Login failed. Please try again.');
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
                            padding: EdgeInsets.fromLTRB(32, 12, 32, 28 + bottomInset),
                            child: _FormSection(
                              usernameCtrl: _usernameCtrl,
                              passCtrl: _passCtrl,
                              showPassword: _showPassword,
                              loading: _loading,
                              error: _error,
                              onToggleShowPassword: () =>
                                  setState(() => _showPassword = !_showPassword),
                              onForgotPassword: () {
                                // TODO
                              },
                              onSignIn: _signIn,
                              onSignUp: () {
                                Navigator.pushNamed(context, '/signup');
                              },
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
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _BrandLogo(),
          SizedBox(height: 18),
          Text(
            'Welcome Back',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
              height: 1.15,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Sign in to continue managing your finances',
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

/// ---------------- Form ----------------

class _FormSection extends StatelessWidget {
  final TextEditingController usernameCtrl;
  final TextEditingController passCtrl;
  final bool showPassword;
  final bool loading;
  final String? error;
  final VoidCallback onToggleShowPassword;
  final VoidCallback onForgotPassword;
  final VoidCallback onSignIn;
  final VoidCallback onSignUp;

  const _FormSection({
    required this.usernameCtrl,
    required this.passCtrl,
    required this.showPassword,
    required this.loading,
    required this.error,
    required this.onToggleShowPassword,
    required this.onForgotPassword,
    required this.onSignIn,
    required this.onSignUp,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Label('Username'),
        const SizedBox(height: 8),
        _TextFieldPill(
          controller: usernameCtrl,
          hint: 'Enter your username',
          keyboardType: TextInputType.text,
          obscureText: false,
          enabled: !loading,
        ),
        const SizedBox(height: 18),

        const _Label('Password'),
        const SizedBox(height: 8),
        _PasswordFieldPill(
          controller: passCtrl,
          hint: 'Enter your password',
          obscureText: !showPassword,
          onToggle: onToggleShowPassword,
          isShowing: showPassword,
          enabled: !loading,
        ),

        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: loading ? null : onForgotPassword,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: const Text(
              'Forgot Password?',
              style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w600),
            ),
          ),
        ),

        if (error != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Text(
              error!,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],

        const SizedBox(height: 10),
        _GradientButton(
          text: loading ? 'Signing In...' : 'Sign In',
          enabled: !loading,
          onTap: onSignIn,
        ),

        const SizedBox(height: 18),

        Center(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text("Don't have an account? ",
                  style: TextStyle(color: Color(0xFF4B5563))),
              GestureDetector(
                onTap: loading ? null : onSignUp,
                child: const Text(
                  'Sign Up',
                  style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
  final bool enabled;

  const _TextFieldPill({
    required this.controller,
    required this.hint,
    required this.keyboardType,
    required this.obscureText,
    required this.enabled,
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
        enabled: enabled,
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
  final bool enabled;

  const _PasswordFieldPill({
    required this.controller,
    required this.hint,
    required this.obscureText,
    required this.onToggle,
    required this.isShowing,
    required this.enabled,
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
              enabled: enabled,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: enabled ? onToggle : null,
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
