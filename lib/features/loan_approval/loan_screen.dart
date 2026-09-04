import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/formatters/rm_currency.dart';
import '../../core/widgets/loading_skeletons.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/mock_data.dart';
import 'loan_manager.dart';
import 'loan_validators.dart';

String _submittedDate(BuildContext context, LoanRequest request) {
  final date = request.submittedAt.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return 'Submitted • ${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
}

Future<bool> _confirmLoanAction(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;
}

class LoanScreen extends StatelessWidget {
  final bool isBanker;

  const LoanScreen({super.key, required this.isBanker});

  @override
  Widget build(BuildContext context) {
    return isBanker ? const _BankerView() : const _SmeView();
  }
}

class _SmeView extends StatefulWidget {
  const _SmeView();

  @override
  State<_SmeView> createState() => _SmeViewState();
}

class _SmeViewState extends State<_SmeView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _companyCtrl;
  late final TextEditingController _amountCtrl;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    final manager = context.read<LoanManager>();
    _companyCtrl = TextEditingController(text: manager.formCompanyName);
    _amountCtrl = TextEditingController(text: manager.formLoanAmount);
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitApplication() async {
    final manager = context.read<LoanManager>();
    manager.showFormValidation();
    if (!_formKey.currentState!.validate()) return;
    if (_confirming || manager.isSaving) return;
    final editing = manager.isEditing;
    final editingId = manager.editingId;
    if (editing) {
      _confirming = true;
      final confirmed = await _confirmLoanAction(
        context,
        title: 'Confirm Update',
        message: 'Are you sure you want to update this loan application?',
        action: 'Update',
      );
      if (!mounted) return;
      _confirming = false;
      if (!confirmed || manager.editingId != editingId) return;
    }
    final error = await manager.saveForm();
    if (!mounted) return;

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

    AppSnackBar.success(
      context,
      editing
          ? 'Application updated successfully.'
          : 'Loan application submitted',
    );
  }

  Future<void> _deleteApplication(String id) async {
    if (_confirming) return;
    final manager = context.read<LoanManager>();
    _confirming = true;
    final confirmed = await _confirmLoanAction(
      context,
      title: 'Delete Application?',
      message: 'This action cannot be undone.',
      action: 'Delete',
    );
    if (!mounted) return;
    _confirming = false;
    if (!confirmed) return;
    final error = await manager.deletePending(id);
    if (!mounted) return;
    if (error != null) {
      AppSnackBar.error(context, error);
    } else {
      AppSnackBar.success(context, 'Application deleted successfully.');
    }
  }

  Widget _buildApplicationForm(BuildContext context) {
    final manager = context.watch<LoanManager>();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          autovalidateMode: manager.formValidationVisible
              ? AutovalidateMode.always
              : AutovalidateMode.disabled,
          child: AbsorbPointer(
            absorbing: manager.isSaving,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: AppColors.accentBlue,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        manager.isEditing
                            ? 'Edit Loan Application'
                            : 'New Loan Application',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textColor(context),
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _companyCtrl,
                  decoration: appInputDecoration(
                    label: 'Company Name',
                    hint: 'e.g. TechVision Sdn Bhd',
                    prefixIcon: Icons.business,
                  ).copyWith(errorMaxLines: 3),
                  validator: validateLoanCompany,
                  onChanged: manager.updateFormCompanyName,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    '${manager.editingId}-${manager.formEquipmentType}',
                  ),
                  initialValue: manager.formEquipmentType,
                  isExpanded: true,
                  decoration: appInputDecoration(
                    label: 'Equipment Type',
                    prefixIcon: Icons.precision_manufacturing,
                  ),
                  items: MockData.equipmentTypes
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(e, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) manager.updateFormEquipmentType(v);
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _amountCtrl,
                  decoration: appInputDecoration(
                    label: 'Loan Amount (RM)',
                    hint: 'e.g. 150000.00',
                    prefixIcon: Icons.attach_money,
                  ).copyWith(errorMaxLines: 3),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: validateLoanAmount,
                  onChanged: manager.updateFormLoanAmount,
                ),
                const SizedBox(height: 14),
                Text(
                  'Interest Rate: ${manager.formInterestRate.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textColor(context),
                  ),
                ),
                Slider(
                  value: manager.formInterestRate.clamp(1.0, 12.0),
                  min: 1.0,
                  max: 12.0,
                  divisions: 44,
                  activeColor: AppColors.accentBlue,
                  label: '${manager.formInterestRate.toStringAsFixed(2)}%',
                  onChanged: manager.updateFormInterestRate,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: manager.isSaving || !manager.isFormValid
                        ? null
                        : _submitApplication,
                    icon: const Icon(Icons.send),
                    label: Text(
                      manager.isEditing
                          ? 'Update Application'
                          : 'Submit Application',
                    ),
                  ),
                ),
                if (manager.isEditing)
                  TextButton(
                    onPressed: manager.isSaving ? null : manager.clearLoanForm,
                    child: const Text('Cancel'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApplications(BuildContext context, List<LoanRequest> requests) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: context.watch<LoanManager>().isLoading
          ? const LoanApplicationsSkeleton()
          : _buildApplicationsContent(context, requests),
    );
  }

  Widget _buildApplicationsContent(
    BuildContext context,
    List<LoanRequest> requests,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<LoanFilter>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: LoanFilter.all, label: Text('All')),
              ButtonSegment(value: LoanFilter.pending, label: Text('Pending')),
              ButtonSegment(
                value: LoanFilter.approved,
                label: Text('Approved'),
              ),
              ButtonSegment(
                value: LoanFilter.rejected,
                label: Text('Rejected'),
              ),
            ],
            selected: {context.watch<LoanManager>().filter},
            onSelectionChanged: (values) =>
                context.read<LoanManager>().setFilter(values.single),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.history, color: AppTheme.mutedColor(context), size: 20),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'My Applications (${requests.length})',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.mutedColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (requests.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: AppTheme.subtleColor(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No applications yet',
                      style: TextStyle(color: AppTheme.mutedColor(context)),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...requests.reversed.map(
            (req) => _SmeRequestCard(
              request: req,
              onDelete: () => _deleteApplication(req.id),
              onEdit: () async {
                final error = context.read<LoanManager>().startEditing(req.id);
                if (error != null) {
                  AppSnackBar.error(context, error);
                  return;
                }
                await WidgetsBinding.instance.endOfFrame;
                if (!mounted) return;
                final formContext = _formKey.currentContext;
                if (formContext != null && formContext.mounted) {
                  Scrollable.ensureVisible(formContext);
                }
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<LoanManager>();
    final requests = manager.filteredRequests;
    _syncController(_companyCtrl, manager.formCompanyName);
    _syncController(_amountCtrl, manager.formLoanAmount);

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
                    Expanded(flex: 5, child: _buildApplicationForm(context)),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 6,
                      child: _buildApplications(context, requests),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildApplicationForm(context),
                    const SizedBox(height: 24),
                    _buildApplications(context, requests),
                  ],
                ),
        );
      },
    );
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}

class _SmeRequestCard extends StatelessWidget {
  final LoanRequest request;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _SmeRequestCard({
    required this.request,
    required this.onEdit,
    required this.onDelete,
  });

  Color _statusColor() {
    switch (request.status) {
      case LoanStatus.pending:
        return AppColors.warning;
      case LoanStatus.approved:
        return AppColors.success;
      case LoanStatus.notApproved:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _statusColor().withValues(alpha: 0.15),
          child: Text(
            request.status.icon,
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          request.equipmentName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${request.companyName} · ${formatRm(request.loanAmount)}',
              style: TextStyle(color: AppTheme.mutedColor(context)),
            ),
            Text(
              _submittedDate(context, request),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (request.status == LoanStatus.pending)
              Wrap(
                children: [
                  IconButton(
                    tooltip: 'Edit application',
                    key: ValueKey('edit-${request.id}'),
                    onPressed: context.watch<LoanManager>().isSaving
                        ? null
                        : onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Delete application',
                    key: ValueKey('delete-${request.id}'),
                    onPressed: context.watch<LoanManager>().isSaving
                        ? null
                        : onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _statusColor().withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _statusColor(), width: 1),
          ),
          child: Text(
            request.status.label,
            style: TextStyle(
              color: _statusColor(),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _BankerView extends StatelessWidget {
  const _BankerView();

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: context.watch<LoanManager>().isLoading
          ? const SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16),
              child: LoanApplicationsSkeleton(),
            )
          : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final manager = context.watch<LoanManager>();
    final requests = manager.allRequests;

    if (requests.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 64,
                    color: AppTheme.subtleColor(context),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No loan applications to review',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.mutedColor(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        return Dismissible(
          key: ValueKey(req.id),
          direction: req.status == LoanStatus.pending
              ? DismissDirection.endToStart
              : DismissDirection.none,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.delete_forever,
              color: Colors.white,
              size: 28,
            ),
          ),
          confirmDismiss: (direction) async {
            if (manager.isSaving) return false;
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Application?'),
                content: const Text('This action cannot be undone.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            if (!context.mounted || confirmed != true) return false;
            final error = await manager.deletePending(req.id);
            if (context.mounted) {
              if (error != null) {
                AppSnackBar.error(context, error);
              } else {
                AppSnackBar.success(
                  context,
                  'Application deleted successfully.',
                );
              }
            }
            return false;
          },
          child: _BankerRequestCard(request: req),
        );
      },
    );
  }
}

class _BankerRequestCard extends StatelessWidget {
  final LoanRequest request;
  const _BankerRequestCard({required this.request});

  Color _statusColor() {
    switch (request.status) {
      case LoanStatus.pending:
        return AppColors.warning;
      case LoanStatus.approved:
        return AppColors.success;
      case LoanStatus.notApproved:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.read<LoanManager>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.bankerTeal.withValues(alpha: 0.12),
                  child: const Icon(
                    Icons.business,
                    color: AppColors.bankerTeal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.companyName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        request.equipmentName,
                        style: TextStyle(
                          color: AppTheme.mutedColor(context),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor(), width: 1),
                  ),
                  child: Text(
                    request.status.label,
                    style: TextStyle(
                      color: _statusColor(),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _submittedDate(context, request),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _DetailChip(
                  icon: Icons.attach_money,
                  label: formatRm(request.loanAmount),
                ),
                _DetailChip(
                  icon: Icons.percent,
                  label: '${request.interestRate.toStringAsFixed(2)}%',
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (request.status == LoanStatus.pending) ...[
              const Divider(),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final error = await manager.updateStatus(
                          request.id,
                          LoanStatus.notApproved,
                        );
                        if (!context.mounted) return;
                        if (error == null) {
                          AppSnackBar.success(context, 'Loan rejected');
                        }
                        if (context.mounted && error != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ $error'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final error = await manager.updateStatus(
                          request.id,
                          LoanStatus.approved,
                        );
                        if (!context.mounted) return;
                        if (error == null) {
                          AppSnackBar.success(context, 'Loan approved');
                        }
                        if (context.mounted && error != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ $error'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _DetailChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.mutedColor(context)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textColor(context),
            ),
          ),
        ],
      ),
    );
  }
}
