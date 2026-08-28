import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import 'auth_manager.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _companyCtrl;
  late TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthManager>().currentUser;
    _nameCtrl = TextEditingController(text: user?.fullName ?? '');
    _companyCtrl = TextEditingController(text: user?.companyName ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _companyCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    if (_isEditing) {
      final auth = context.read<AuthManager>();
      auth.updateProfile(
        fullName: _nameCtrl.text,
        companyName: _companyCtrl.text,
        phone: _phoneCtrl.text,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Profile updated!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
    setState(() => _isEditing = !_isEditing);
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
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthManager>().logout();
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
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.darkGrey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user.email,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.mediumGrey, fontSize: 14),
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
                      color: AppColors.darkGrey,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _toggleEdit,
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
              isEditing: _isEditing && !auth.isBanker,
            ),
            const SizedBox(height: 16),
            _ProfileField(
              label: 'Phone',
              icon: Icons.phone_outlined,
              controller: _phoneCtrl,
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
            style: TextStyle(color: AppColors.mediumGrey, fontSize: 12),
          ),
          trailing: const Icon(
            Icons.chevron_right,
            color: AppColors.mediumGrey,
          ),
          onTap: _handleLogout,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                              color: AppColors.mediumGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 3,
                      child: _buildInformationCard(context, auth, user),
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
                    _buildLogoutCard(),
                    const SizedBox(height: 28),
                    Text(
                      'BNM SME Platform v0.1.0',
                      style: TextStyle(
                        color: AppColors.mediumGrey,
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

  const _ProfileField({
    required this.label,
    required this.icon,
    this.value,
    this.controller,
    required this.isEditing,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = value ?? controller?.text ?? '';

    if (isEditing && controller != null) {
      return TextFormField(
        controller: controller,
        decoration: appInputDecoration(label: label, prefixIcon: icon),
      );
    }

    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.mediumGrey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.mediumGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                displayValue.isNotEmpty ? displayValue : '—',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkGrey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
