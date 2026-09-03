import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/responsive_input_dialog.dart';
import 'auth_manager.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _noticeScheduled = false;

  int _tapCount = 0;
  Timer? _tapTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_noticeScheduled) return;
    _noticeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notice = context.read<AuthManager>().takeNotice();
      if (notice != null) {
        _showError(notice);
      }
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _tapTimer?.cancel();
    super.dispose();
  }

  void _onLogoTap() {
    _tapCount++;

    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(seconds: 3), () {
      _tapCount = 0;
    });

    if (_tapCount >= 7) {
      _tapCount = 0;
      _tapTimer?.cancel();
      _showBankerDialog();
    } else if (_tapCount >= 4) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You are ${7 - _tapCount} steps away from developer mode...',
            style: const TextStyle(fontSize: 13),
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: AppColors.darkGrey,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _onLogoLongPress() {
    _tapCount = 0;
    _tapTimer?.cancel();
    _showBankerDialog();
  }

  Future<void> _showBankerDialog() async {
    final credentials = await showDialog<_BankerCredentials>(
      context: context,
      useSafeArea: false,
      builder: (_) => const _BankerLoginDialog(),
    );

    if (!mounted || credentials == null) return;
    setState(() => _isLoading = true);
    final result = await context.read<AuthManager>().bankerLogin(
      email: credentials.email,
      password: credentials.password,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result != null) {
      _showError(result);
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final auth = context.read<AuthManager>();
    final error = await auth.login(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );
    if (!mounted) return;

    setState(() => _isLoading = false);
    if (error != null) {
      _showError(error);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $message'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildBrand(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final logoSize = (shortestSide * 0.2).clamp(64.0, 96.0);

    return GestureDetector(
      onTap: _onLogoTap,
      onLongPress: _onLogoLongPress,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: logoSize,
            height: logoSize,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryRed, AppColors.primaryRedDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryRed.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              Icons.account_balance,
              color: Colors.white,
              size: logoSize * 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'BNM SME Platform',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.textColor(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Automation Equipment Financing',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.mutedColor(context),
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome Back',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sign in to your SME account',
                style: TextStyle(
                  color: AppTheme.mutedColor(context),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailCtrl,
                decoration: appInputDecoration(
                  label: 'Email',
                  hint: 'your@email.com',
                  prefixIcon: Icons.email_outlined,
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!v.contains('@') || !v.contains('.')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                decoration:
                    appInputDecoration(
                      label: 'Password',
                      prefixIcon: Icons.lock_outline,
                    ).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppTheme.mutedColor(context),
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Password is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDemoCard() {
    return Card(
      margin: EdgeInsets.zero,
      color: AppTheme.subtleColor(context).withValues(alpha: 0.5),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.center,
              children: [
                Icon(Icons.flash_on, size: 16, color: AppColors.accentBlue),
                Text(
                  'Quick Demo Accounts (Tap to auto-fill)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.mutedColor(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.person, size: 16),
                  label: const Text('SME Demo 1'),
                  onPressed: () {
                    setState(() {
                      _emailCtrl.text = 'sme@techvision.com';
                      _passwordCtrl.text = 'password123';
                    });
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.person_outline, size: 16),
                  label: const Text('SME Demo 2'),
                  onPressed: () {
                    setState(() {
                      _emailCtrl.text = 'demo@sme.my';
                      _passwordCtrl.text = 'password123';
                    });
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.account_balance, size: 16),
                  label: const Text('Banker Demo'),
                  onPressed: () {
                    setState(() {
                      _emailCtrl.text = 'banker@bnm.gov.my';
                      _passwordCtrl.text = 'password123';
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignupPrompt(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: TextStyle(color: AppTheme.mutedColor(context)),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SignupScreen()),
            );
          },
          child: const Text(
            'Sign Up',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape =
                MediaQuery.orientationOf(context) == Orientation.landscape;
            final useTwoPane = isLandscape && constraints.maxWidth >= 600;
            final horizontalPadding = constraints.maxWidth >= 900 ? 48.0 : 24.0;
            final formSection = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLoginCard(context),
                const SizedBox(height: 16),
                _buildDemoCard(),
                const SizedBox(height: 12),
                _buildSignupPrompt(context),
              ],
            );

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 24,
              ),
              child: useTwoPane
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(flex: 2, child: _buildBrand(context)),
                        const SizedBox(width: 32),
                        Expanded(flex: 3, child: formSection),
                      ],
                    )
                  : Column(
                      children: [
                        _buildBrand(context),
                        const SizedBox(height: 32),
                        formSection,
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _BankerCredentials {
  final String email;
  final String password;

  const _BankerCredentials(this.email, this.password);
}

class _BankerLoginDialog extends StatefulWidget {
  const _BankerLoginDialog();

  @override
  State<_BankerLoginDialog> createState() => _BankerLoginDialogState();
}

class _BankerLoginDialogState extends State<_BankerLoginDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _errorText = 'Email and password are required.');
      return;
    }
    Navigator.of(context).pop(
      _BankerCredentials(
        _emailController.text.trim(),
        _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveInputDialog(
      title: Row(
        children: [
          Icon(Icons.account_balance, color: AppColors.bankerTeal, size: 24),
          const SizedBox(width: 8),
          const Expanded(child: Text('Banker Access')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sign in with a Supabase account that has the banker role.',
            style: TextStyle(
              color: AppTheme.mutedColor(context),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            autofocus: true,
            decoration: appInputDecoration(
              label: 'Banker Email',
              hint: 'banker@example.com',
              prefixIcon: Icons.email_outlined,
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _passwordFocusNode.requestFocus(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            obscureText: true,
            decoration: appInputDecoration(
              label: 'Password',
              prefixIcon: Icons.lock_outline,
            ).copyWith(errorText: _errorText),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.login, size: 18),
          label: const Text('Enter'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.bankerTeal,
          ),
        ),
      ],
    );
  }
}
