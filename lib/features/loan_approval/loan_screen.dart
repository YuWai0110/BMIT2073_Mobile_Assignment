import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/mock_data.dart';
import 'loan_manager.dart';

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
  final _companyCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _selectedEquipment = MockData.equipmentTypes.first;
  double _interestRate = 4.5;

  @override
  void dispose() {
    _companyCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _submitApplication() {
    if (!_formKey.currentState!.validate()) return;

    final manager = context.read<LoanManager>();
    final req = LoanRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      companyName: _companyCtrl.text.trim(),
      equipmentName: _selectedEquipment,
      loanAmount: double.parse(_amountCtrl.text.trim()),
      interestRate: _interestRate,
    );
    manager.addLoanRequest(req);

    _companyCtrl.clear();
    _amountCtrl.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✅ Loan application submitted!'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requests = context.watch<LoanManager>().allRequests;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description_outlined,
                          color: AppColors.accentBlue, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'New Loan Application',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkGrey,
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
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    initialValue: _selectedEquipment,
                    decoration: appInputDecoration(
                      label: 'Equipment Type',
                      prefixIcon: Icons.precision_manufacturing,
                    ),
                    items: MockData.equipmentTypes
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedEquipment = v);
                    },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _amountCtrl,
                    decoration: appInputDecoration(
                      label: 'Loan Amount (RM)',
                      hint: 'e.g. 150000',
                      prefixIcon: Icons.attach_money,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (double.tryParse(v.trim()) == null) {
                        return 'Enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'Interest Rate: ${_interestRate.toStringAsFixed(2)}%',
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, color: AppColors.darkGrey),
                  ),
                  Slider(
                    value: _interestRate,
                    min: 1.0,
                    max: 12.0,
                    divisions: 44,
                    activeColor: AppColors.accentBlue,
                    label: '${_interestRate.toStringAsFixed(2)}%',
                    onChanged: (v) => setState(() => _interestRate = v),
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitApplication,
                      icon: const Icon(Icons.send),
                      label: const Text('Submit Application'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        Row(
          children: [
            const SizedBox(width: 16),
            Icon(Icons.history, color: AppColors.mediumGrey, size: 20),
            const SizedBox(width: 6),
            Text(
              'My Applications (${requests.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.mediumGrey,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (requests.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 48, color: AppColors.lightGrey),
                    const SizedBox(height: 8),
                    Text('No applications yet',
                        style: TextStyle(color: AppColors.mediumGrey)),
                  ],
                ),
              ),
            ),
          )
        else
          ...requests.reversed.map((req) => _SmeRequestCard(request: req)),
      ],
    );
  }
}

class _SmeRequestCard extends StatelessWidget {
  final LoanRequest request;
  const _SmeRequestCard({required this.request});

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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _statusColor().withValues(alpha: 0.15),
          child: Text(request.status.icon, style: const TextStyle(fontSize: 20)),
        ),
        title: Text(
          request.equipmentName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${request.companyName} · RM ${request.loanAmount.toStringAsFixed(0)}',
          style: const TextStyle(color: AppColors.mediumGrey),
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
    final manager = context.watch<LoanManager>();
    final requests = manager.allRequests;

    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 64, color: AppColors.lightGrey),
            const SizedBox(height: 12),
            Text(
              'No loan applications to review',
              style: TextStyle(
                  fontSize: 16,
                  color: AppColors.mediumGrey,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        return Dismissible(
          key: ValueKey(req.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete_forever, color: Colors.white, size: 28),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Application?'),
                content: Text(
                    'Remove ${req.companyName}\'s application permanently?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style:
                        TextButton.styleFrom(foregroundColor: AppColors.error),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
          },
          onDismissed: (_) => manager.deleteRequest(req.id),
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
                  child: const Icon(Icons.business,
                      color: AppColors.bankerTeal, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.companyName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        request.equipmentName,
                        style: const TextStyle(
                            color: AppColors.mediumGrey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

            Row(
              children: [
                _DetailChip(
                    icon: Icons.attach_money,
                    label: 'RM ${request.loanAmount.toStringAsFixed(0)}'),
                const SizedBox(width: 12),
                _DetailChip(
                    icon: Icons.percent,
                    label: '${request.interestRate.toStringAsFixed(2)}%'),
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
                      onPressed: () => manager.updateStatus(
                          request.id, LoanStatus.notApproved),
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
                      onPressed: () => manager.updateStatus(
                          request.id, LoanStatus.approved),
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
        color: AppColors.backgroundGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.mediumGrey),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkGrey)),
        ],
      ),
    );
  }
}
