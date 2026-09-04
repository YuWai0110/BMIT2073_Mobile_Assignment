import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/widgets/loading_skeletons.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/theme/theme_manager.dart';
import 'auth_manager.dart';
import 'profile_manager.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: context.read<AuthManager>().profileManager,
    child: const _ProfileEditor(),
  );
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor();

  @override
  State<_ProfileEditor> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<_ProfileEditor> {
  late ProfileManager _manager;
  bool _syncing = false;
  bool _confirming = false;
  bool get _isEditing => _manager.isEditing;

  late TextEditingController _nameCtrl;
  late TextEditingController _companyCtrl;
  late TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    _manager = context.read<ProfileManager>();
    _nameCtrl = TextEditingController.fromValue(_manager.fullName);
    _companyCtrl = TextEditingController.fromValue(_manager.company);
    _phoneCtrl = TextEditingController.fromValue(_manager.phone);
    _nameCtrl.addListener(_writeDraft);
    _companyCtrl.addListener(_writeDraft);
    _phoneCtrl.addListener(_writeDraft);
    _manager.addListener(_readDraft);
  }

  void _writeDraft() {
    if (_syncing || !_isEditing) return;
    _manager.updateDraft(
      name: _nameCtrl.value,
      companyValue: _companyCtrl.value,
      phoneValue: _phoneCtrl.value,
    );
  }

  void _readDraft() {
    if (!mounted) return;
    _syncing = true;
    if (_nameCtrl.value != _manager.fullName) {
      _nameCtrl.value = _manager.fullName;
    }
    if (_companyCtrl.value != _manager.company) {
      _companyCtrl.value = _manager.company;
    }
    if (_phoneCtrl.value != _manager.phone) _phoneCtrl.value = _manager.phone;
    _syncing = false;
  }

  @override
  void dispose() {
    _manager.removeListener(_readDraft);
    _nameCtrl.dispose();
    _companyCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleEdit() async {
    if (_confirming || _manager.isSaving) return;
    if (_isEditing) {
      if (!_manager.isValid) return;
      final owner = context.read<AuthManager>().currentUser?.id;
      _confirming = true;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm Profile Update'),
          content: const Text('Are you sure you want to save these changes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      _confirming = false;
      if (confirmed != true ||
          context.read<AuthManager>().currentUser?.id != owner) {
        return;
      }
      final error = await _manager.save();
      if (!mounted) return;
      if (context.read<AuthManager>().currentUser?.id != owner) return;

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $error'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }
      AppSnackBar.success(context, 'Profile updated successfully');
    } else {
      _manager.startEditing();
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final auth = context.read<AuthManager>();
              Navigator.pop(ctx);
              await auth.logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    AuthManager auth,
    UserAccount user,
  ) {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: auth.isBanker
                ? AppColors.bankerTeal
                : AppColors.primaryRed,
            child: Text(
              user.initials,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.fullName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.mutedColor(context), fontSize: 14),
          ),
          if (auth.isBanker) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.bankerTeal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.bankerTeal, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, color: AppColors.bankerTeal, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Banker Account',
                    style: TextStyle(
                      color: AppColors.bankerTeal,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInformationCard(
    BuildContext context,
    AuthManager auth,
    UserAccount user,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  color: AppColors.accentBlue,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Profile Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed:
                      _manager.isSaving || (_isEditing && !_manager.isValid)
                      ? null
                      : _toggleEdit,
                  icon: Icon(_isEditing ? Icons.save : Icons.edit, size: 18),
                  label: Text(_isEditing ? 'Save' : 'Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: _isEditing
                        ? AppColors.success
                        : AppColors.accentBlue,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _ProfileField(
              label: 'Full Name',
              icon: Icons.badge_outlined,
              controller: _nameCtrl,
              validator: ProfileManager.validateName,
              readOnly: _manager.isSaving,
              isEditing: _isEditing && !auth.isBanker,
            ),
            const SizedBox(height: 16),
            _ProfileField(
              label: 'Email',
              icon: Icons.email_outlined,
              value: user.email,
              isEditing: false,
            ),
            const SizedBox(height: 16),
            _ProfileField(
              label: 'Company',
              icon: Icons.business,
              controller: _companyCtrl,
              validator: ProfileManager.validateCompany,
              readOnly: _manager.isSaving,
              isEditing: _isEditing && !auth.isBanker,
            ),
            const SizedBox(height: 16),
            _ProfileField(
              label: 'Phone',
              icon: Icons.phone_outlined,
              controller: _phoneCtrl,
              validator: ProfileManager.validatePhone,
              readOnly: _manager.isSaving,
              isEditing: _isEditing && !auth.isBanker,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.error.withValues(alpha: 0.1),
            child: const Icon(Icons.logout, color: AppColors.error),
          ),
          title: const Text(
            'Logout',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.error,
            ),
          ),
          subtitle: Text(
            'Sign out of your account',
            style: TextStyle(color: AppTheme.mutedColor(context), fontSize: 12),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: AppTheme.mutedColor(context),
          ),
          onTap: _handleLogout,
        ),
      ),
    );
  }

  Widget _buildThemeCard(BuildContext context) {
    final manager = context.watch<ThemeManager>();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Theme', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Center(
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                  ButtonSegment(value: ThemeMode.system, label: Text('System')),
                ],
                selected: {manager.themeMode},
                onSelectionChanged: (selection) async {
                  final saved = await manager.setThemeMode(selection.single);
                  if (!context.mounted || saved) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Unable to save theme preference. Please try again.',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ProfileManager>();
    final loading = context.watch<AuthManager>().isProfileLoading;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: loading
          ? const ProfileSkeleton()
          : KeyedSubtree(
              key: const ValueKey('profile-content'),
              child: _buildContent(context),
            ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final auth = context.watch<AuthManager>();
    final user = auth.currentUser;

    if (user == null) {
      return const Center(child: Text('Not logged in'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape =
            MediaQuery.orientationOf(context) == Orientation.landscape;
        final useTwoPane = isLandscape && constraints.maxWidth >= 700;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: useTwoPane
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _buildProfileHeader(context, auth, user),
                          const SizedBox(height: 24),
                          _buildLogoutCard(),
                          const SizedBox(height: 20),
                          Text(
                            'BNM SME Platform v0.1.0',
                            style: TextStyle(
                              color: AppTheme.mutedColor(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          _buildInformationCard(context, auth, user),
                          const SizedBox(height: 16),
                          _buildThemeCard(context),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildProfileHeader(context, auth, user),
                    const SizedBox(height: 28),
                    _buildInformationCard(context, auth, user),
                    const SizedBox(height: 16),
                    _buildThemeCard(context),
                    const SizedBox(height: 16),
                    _buildLogoutCard(),
                    const SizedBox(height: 28),
                    Text(
                      'BNM SME Platform v0.1.0',
                      style: TextStyle(
                        color: AppTheme.mutedColor(context),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
        );
      },
    );
  }
}

class _ProfileField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final TextEditingController? controller;
  final bool isEditing;
  final String? Function(String?)? validator;
  final bool readOnly;

  const _ProfileField({
    required this.label,
    required this.icon,
    this.value,
    this.controller,
    required this.isEditing,
    this.validator,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = value ?? controller?.text ?? '';

    if (isEditing && controller != null) {
      return TextFormField(
        key: ValueKey(label),
        controller: controller,
        validator: validator,
        autovalidateMode: AutovalidateMode.always,
        readOnly: readOnly,
        decoration: appInputDecoration(label: label, prefixIcon: icon),
      );
    }

    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.mutedColor(context)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.mutedColor(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                displayValue.isNotEmpty ? displayValue : '—',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textColor(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
