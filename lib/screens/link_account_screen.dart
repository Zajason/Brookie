import 'package:flutter/material.dart';
import '../shell/app_shell.dart';
import '../models/bank.dart';
import '../services/expense_service.dart';

class LinkAccountScreen extends StatefulWidget {
  const LinkAccountScreen({super.key});

  @override
  State<LinkAccountScreen> createState() => _LinkAccountScreenState();
}

class _LinkAccountScreenState extends State<LinkAccountScreen> with TickerProviderStateMixin {
  static const List<Bank> popularBanks = [
    Bank(name: 'Chase Bank', logo: '🏦'),
    Bank(name: 'Bank of America', logo: '🏛️'),
    Bank(name: 'Wells Fargo', logo: '🏢'),
    Bank(name: 'Citibank', logo: '🏪'),
    Bank(name: 'Capital One', logo: '💳'),
  ];

  Bank? selectedBank;
  bool showBankList = false;
  bool isConnecting = false;

  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  String accountType = 'Checking';

  late final AnimationController _fieldsAnim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  bool get canConnect {
    final user = usernameCtrl.text.trim();
    final pass = passwordCtrl.text.trim();

    // Username must look like an email OR be long enough
    final validUser = user.contains('@') || user.length > 4;

    // Password must be strong-ish (e.g., 6+ chars)
    final validPass = pass.length >= 6;

    return selectedBank != null && validUser && validPass;
  }

  @override
  void initState() {
    super.initState();
    _fieldsAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fade = CurvedAnimation(parent: _fieldsAnim, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fieldsAnim, curve: Curves.easeOut));

    usernameCtrl.addListener(() => setState(() {}));
    passwordCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    usernameCtrl.dispose();
    passwordCtrl.dispose();
    _fieldsAnim.dispose();
    super.dispose();
  }

  void _selectBank(Bank b) {
    setState(() {
      selectedBank = b;
      showBankList = false;
    });
    _fieldsAnim.forward(from: 0);
  }

  Future<void> _handleConnect() async {
    if (!canConnect) return;

    setState(() => isConnecting = true); // Start Spinner

    try {
      // Fake the "Connection" delay (Authentication simulation)
      await Future.delayed(const Duration(seconds: 2));
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${selectedBank!.name}! Downloading history...')),
      );

      // Trigger the AI Backfill
      // We assume you have a provider or can access ExpenseService()
      final service = ExpenseService(); // Or context.read<ExpenseService>()
      final count = await service.generateAndSaveBackfill(accountType);

      if (!mounted) return;

      // Success
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Success! Imported $count transactions.'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Close the screen and go back to Dashboard
      Navigator.of(context).pushNamedAndRemoveUntil('/budget', (route) => false);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFF9FAFB)],
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 64, 20, 18),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.of(context).maybePop(),
                          borderRadius: BorderRadius.circular(999),
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.chevron_left_rounded, size: 28, color: Color(0xFF374151)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Link Account',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Connect your bank account to automatically track spending',
                      style: TextStyle(color: Colors.grey.shade600, height: 1.3),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SecurityBadge(),
                      const SizedBox(height: 18),

                      _BankSelector(
                        selectedBankName: selectedBank?.name,
                        isOpen: showBankList,
                        onToggle: () => setState(() => showBankList = !showBankList),
                      ),

                      if (showBankList) ...[
                        const SizedBox(height: 10),
                        _BankDropdown(
                          banks: popularBanks,
                          onSelect: _selectBank,
                        ),
                      ],

                      if (selectedBank != null) ...[
                        const SizedBox(height: 18),
                        _DividerWithText(text: "Enter your credentials"),

                        const SizedBox(height: 14),
                        SlideTransition(
                          position: _slide,
                          child: FadeTransition(
                            opacity: _fade,
                            child: Column(
                              children: [
                                _LabeledField(
                                  label: "Username or Email",
                                  icon: Icons.mail_outline_rounded,
                                  controller: usernameCtrl,
                                  hint: "Enter your username",
                                  obscure: false,
                                ),
                                const SizedBox(height: 14),
                                _LabeledField(
                                  label: "Password",
                                  icon: Icons.lock_outline_rounded,
                                  controller: passwordCtrl,
                                  hint: "Enter your password",
                                  obscure: true,
                                ),
                                const SizedBox(height: 16),

                                _AccountTypeSelector(
                                  value: accountType,
                                  onChanged: (v) => setState(() => accountType = v),
                                ),

                                const SizedBox(height: 16),
                                const _InfoNote(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom button
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (canConnect && !isConnecting) ? _handleConnect : null, // Disable while loading
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            disabledBackgroundColor: const Color(0xFF3B82F6).withOpacity(0.40),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            elevation: 0,
                          ),
                          child: isConnecting
                            ? const SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text("Connect Account", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Your data is protected with 256-bit encryption",
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------- Components ----------------

class _SecurityBadge extends StatelessWidget {
  const _SecurityBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        border: Border.all(color: const Color(0xFFDBEAFE)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Bank-level security",
                    style: TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  "Your credentials are encrypted and never stored on our servers",
                  style: TextStyle(color: Colors.blue.shade700, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BankSelector extends StatelessWidget {
  final String? selectedBankName;
  final bool isOpen;
  final VoidCallback onToggle;

  const _BankSelector({
    required this.selectedBankName,
    required this.isOpen,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedBankName != null && selectedBankName!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Select your bank", style: TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_outlined, color: Color(0xFF6B7280), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasSelection ? selectedBankName! : "Choose a bank...",
                    style: TextStyle(
                      color: hasSelection ? const Color(0xFF111827) : const Color(0xFF6B7280),
                      fontSize: 14,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: isOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(Icons.expand_more_rounded, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BankDropdown extends StatelessWidget {
  final List<Bank> banks;
  final ValueChanged<Bank> onSelect;

  const _BankDropdown({required this.banks, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < banks.length; i++) ...[
            InkWell(
              onTap: () => onSelect(banks[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Text(banks[i].logo, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        banks[i].name,
                        style: const TextStyle(color: Color(0xFF111827), fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i != banks.length - 1) const Divider(height: 1, color: Color(0xFFF3F4F6)),
          ],
        ],
      ),
    );
  }
}

class _DividerWithText extends StatelessWidget {
  final String text;
  const _DividerWithText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE5E7EB), height: 1)),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(width: 12),
        const Expanded(child: Divider(color: Color(0xFFE5E7EB), height: 1)),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String hint;
  final bool obscure;

  const _LabeledField({
    required this.label,
    required this.icon,
    required this.controller,
    required this.hint,
    required this.obscure,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(18),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
              prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountTypeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _AccountTypeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget btn(String label, bool selected) {
      return Expanded(
        child: InkWell(
          onTap: () => onChanged(label),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF3B82F6) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: selected ? Colors.transparent : const Color(0xFFE5E7EB)),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF374151),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Account Type", style: TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [
            btn("Checking", value == "Checking"),
            const SizedBox(width: 12),
            btn("Savings", value == "Savings"),
          ],
        ),
      ],
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.key_rounded, color: Color(0xFF6B7280), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "We'll securely verify your account and start tracking transactions automatically",
              style: TextStyle(color: Colors.grey.shade700, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
