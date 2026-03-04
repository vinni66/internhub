import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internhub_app/core/theme/app_colors.dart';
import 'package:internhub_app/features/auth/presentation/providers/auth_notifier.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usnController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  int _currentStep = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _usnController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authNotifierProvider.notifier).register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _nameController.text.trim(),
          usn: _usnController.text.trim().isEmpty
              ? null
              : _usnController.text.trim(),
        );
  }

  bool _validateStep0() {
    return _nameController.text.trim().length >= 2 &&
        _emailController.text.contains('@');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthStateLoading;
    final error = authState is AuthStateError ? authState.message : null;
    final registered = authState is AuthStateRegistered;

    if (registered) return _buildSuccessScreen(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  _StepIndicator(current: _currentStep, total: 2),
                  const SizedBox(height: 28),
                  if (error != null) ...[
                    _ErrorBanner(error),
                    const SizedBox(height: 16),
                  ],
                  if (_currentStep == 0) ...[
                    _StepTitle('Personal Info', 'Tell us about yourself'),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v?.trim().length ?? 0) < 2
                          ? 'Enter your full name'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v?.isEmpty ?? true) return 'Email required';
                        if (!v!.contains('@')) return 'Enter valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usnController,
                      decoration: const InputDecoration(
                        labelText: 'USN (optional)',
                        hintText: 'e.g. U21CS001',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                  ],
                  if (_currentStep == 1) ...[
                    _StepTitle('Account Security', 'Create a strong password'),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) {
                        if (v?.isEmpty ?? true) return 'Password required';
                        if ((v?.length ?? 0) < 8)
                          return 'At least 8 characters';
                        if (!v!.contains(RegExp(r'[A-Z]')))
                          return 'Add uppercase letter';
                        if (!v.contains(RegExp(r'[0-9]')))
                          return 'Add a number';
                        return null;
                      },
                    ),
                    _PasswordStrength(_passwordController),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: Icon(Icons.lock_outlined),
                      ),
                      validator: (v) => v != _passwordController.text
                          ? 'Passwords do not match'
                          : null,
                    ),
                  ],
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      if (_currentStep > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _currentStep--),
                            child: const Text('Back'),
                          ),
                        ),
                      if (_currentStep > 0) const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () {
                                    if (_currentStep == 0) {
                                      if (!_validateStep0()) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content:
                                                  Text('Fill required fields')),
                                        );
                                        return;
                                      }
                                      setState(() => _currentStep = 1);
                                    } else {
                                      _submit();
                                    }
                                  },
                            child: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(_currentStep == 0
                                    ? 'Continue'
                                    : 'Create Account'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account? '),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Sign In'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessScreen(BuildContext context) => Scaffold(
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 56),
            ),
            const SizedBox(height: 24),
            const Text('Account Created!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'Check your email to verify your account.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Login'),
            ),
          ]),
        ),
      );
}

// ─── Helper widgets ───────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int current, total;
  const _StepIndicator({required this.current, required this.total});
  @override
  Widget build(BuildContext context) => Row(
        children: List.generate(
          total + 1,
          (i) => Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < total ? 6 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: i <= current ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      );
}

class _StepTitle extends StatelessWidget {
  final String title, subtitle;
  const _StepTitle(this.title, this.subtitle);
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(color: AppColors.textSecondary)),
        ],
      );
}

class _PasswordStrength extends StatefulWidget {
  final TextEditingController controller;
  const _PasswordStrength(this.controller);
  @override
  State<_PasswordStrength> createState() => _PasswordStrengthState();
}

class _PasswordStrengthState extends State<_PasswordStrength> {
  String _pw = '';
  @override
  void initState() {
    super.initState();
    widget.controller
        .addListener(() => setState(() => _pw = widget.controller.text));
  }

  int get _score {
    if (_pw.length < 4) return 0;
    int s = 0;
    if (_pw.length >= 8) s++;
    if (_pw.contains(RegExp(r'[A-Z]'))) s++;
    if (_pw.contains(RegExp(r'[0-9]'))) s++;
    if (_pw.contains(RegExp(r'[^A-Za-z0-9]'))) s++;
    return s;
  }

  Color get _color => [
        AppColors.error,
        AppColors.error,
        AppColors.warning,
        AppColors.success,
        AppColors.success
      ][_score];
  String get _label => ['', 'Weak', 'Fair', 'Good', 'Strong'][_score];

  @override
  Widget build(BuildContext context) {
    if (_pw.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          ...List.generate(
            4,
            (i) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: i < _score ? _color : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(_label, style: TextStyle(color: _color, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String error;
  const _ErrorBanner(this.error);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(error,
                  style:
                      const TextStyle(color: AppColors.error, fontSize: 13))),
        ]),
      );
}

