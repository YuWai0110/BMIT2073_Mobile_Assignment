import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import 'calc_manager.dart';

class CalcScreen extends StatefulWidget {
  const CalcScreen({super.key});

  @override
  State<CalcScreen> createState() => _CalcScreenState();
}

class _CalcScreenState extends State<CalcScreen> {
  final _priceCtrl = TextEditingController(text: '50000');
  final _unitCtrl = TextEditingController(text: '1');
  double _interestRate = 4.5;
  int _loanTermMonths = 36;
  String? _editingId;

  double _monthlyPayment = 0;
  double _totalPayment = 0;
  double _totalInterest = 0;

  static const List<int> _termOptions = [12, 24, 36, 48, 60];

  @override
  void initState() {
    super.initState();
    _recalculate();
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  void _recalculate() {
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final units = int.tryParse(_unitCtrl.text) ?? 1;
    final principal = price * units;

    final result = CalcManager.calculateEMI(
      principal: principal,
      annualRate: _interestRate,
      months: _loanTermMonths,
    );

    setState(() {
      _monthlyPayment = result['monthlyPayment']!;
      _totalPayment = result['totalPayment']!;
      _totalInterest = _totalPayment - principal;
    });
  }

  void _saveScheme() {
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final units = int.tryParse(_unitCtrl.text) ?? 1;

    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid equipment price'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final titleCtrl = TextEditingController(
      text: _editingId != null ? '' : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_editingId != null ? 'Update Scheme' : 'Save Scheme'),
        content: TextField(
          controller: titleCtrl,
          autofocus: true,
          decoration: appInputDecoration(
            label: 'Scheme Name',
            hint: 'e.g. 2026 Factory-A Robotic Arm Plan',
            prefixIcon: Icons.bookmark_border,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleCtrl.text.trim();
              if (title.isEmpty) return;

              final manager = context.read<CalcManager>();
              final scheme = CalcScheme(
                id: _editingId ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                title: title,
                equipmentPrice: price,
                unitCount: units,
                loanTermMonths: _loanTermMonths,
                interestRate: _interestRate,
                monthlyPayment: _monthlyPayment,
                totalPayment: _totalPayment,
              );

              if (_editingId != null) {
                manager.updateScheme(scheme);
                setState(() => _editingId = null);
              } else {
                manager.saveScheme(scheme);
              }

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_editingId != null
                      ? '✅ Scheme updated!'
                      : '✅ Scheme saved!'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: Text(_editingId != null ? 'Update' : 'Save'),
          ),
        ],
      ),
    );
  }

  void _loadScheme(CalcScheme scheme) {
    setState(() {
      _editingId = scheme.id;
      _priceCtrl.text = scheme.equipmentPrice.toStringAsFixed(0);
      _unitCtrl.text = scheme.unitCount.toString();
      _interestRate = scheme.interestRate;
      _loanTermMonths = scheme.loanTermMonths;
    });
    _recalculate();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📋 Loaded "${scheme.title}" — edit and save to update'),
        backgroundColor: AppColors.accentBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schemes = context.watch<CalcManager>().schemes;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calculate_outlined,
                        color: AppColors.accentBlue, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'ROI Calculator',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkGrey,
                              ),
                    ),
                    const Spacer(),
                    if (_editingId != null)
                      TextButton.icon(
                        onPressed: () {
                          setState(() => _editingId = null);
                          _priceCtrl.text = '50000';
                          _unitCtrl.text = '1';
                          _interestRate = 4.5;
                          _loanTermMonths = 36;
                          _recalculate();
                        },
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Clear Edit'),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.error),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _priceCtrl,
                  decoration: appInputDecoration(
                    label: 'Equipment Unit Price (RM)',
                    hint: 'e.g. 50000',
                    prefixIcon: Icons.precision_manufacturing,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _recalculate(),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _unitCtrl,
                  decoration: appInputDecoration(
                    label: 'Quantity (Units)',
                    hint: 'e.g. 3',
                    prefixIcon: Icons.inventory_2_outlined,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _recalculate(),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    const Icon(Icons.percent,
                        size: 18, color: AppColors.mediumGrey),
                    const SizedBox(width: 8),
                    Text(
                      'Annual Interest Rate: ${_interestRate.toStringAsFixed(2)}%',
                      style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.darkGrey),
                    ),
                  ],
                ),
                Slider(
                  value: _interestRate,
                  min: 1.0,
                  max: 15.0,
                  divisions: 56,
                  activeColor: AppColors.accentBlue,
                  label: '${_interestRate.toStringAsFixed(2)}%',
                  onChanged: (v) {
                    setState(() => _interestRate = v);
                    _recalculate();
                  },
                ),
                const SizedBox(height: 8),

                DropdownButtonFormField<int>(
                  initialValue: _loanTermMonths,
                  decoration: appInputDecoration(
                    label: 'Loan Term',
                    prefixIcon: Icons.calendar_month,
                  ),
                  items: _termOptions
                      .map((m) => DropdownMenuItem(
                          value: m, child: Text('$m months (${m ~/ 12} yr${m >= 24 ? "s" : ""})')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _loanTermMonths = v);
                      _recalculate();
                    }
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        Card(
          color: AppColors.accentBlue.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'Calculation Results',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.accentBlue,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _ResultTile(
                            label: 'Monthly Payment',
                            value:
                                'RM ${_monthlyPayment.toStringAsFixed(2)}',
                            icon: Icons.today,
                            color: AppColors.accentBlue)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _ResultTile(
                            label: 'Total Repayment',
                            value:
                                'RM ${_totalPayment.toStringAsFixed(2)}',
                            icon: Icons.account_balance_wallet,
                            color: AppColors.primaryRed)),
                  ],
                ),
                const SizedBox(height: 12),
                _ResultTile(
                  label: 'Total Interest Payable',
                  value: 'RM ${_totalInterest.toStringAsFixed(2)}',
                  icon: Icons.trending_up,
                  color: AppColors.warning,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveScheme,
              icon: Icon(_editingId != null ? Icons.save : Icons.bookmark_add),
              label: Text(_editingId != null
                  ? 'Update Saved Scheme'
                  : 'Save This Scheme'),
            ),
          ),
        ),

        const SizedBox(height: 24),

        Row(
          children: [
            const SizedBox(width: 16),
            Icon(Icons.bookmarks_outlined,
                color: AppColors.mediumGrey, size: 20),
            const SizedBox(width: 6),
            Text(
              'Saved Schemes (${schemes.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.mediumGrey,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (schemes.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.bookmark_border,
                        size: 48, color: AppColors.lightGrey),
                    const SizedBox(height: 8),
                    Text('No saved schemes yet',
                        style: TextStyle(color: AppColors.mediumGrey)),
                  ],
                ),
              ),
            ),
          )
        else
          ...schemes.reversed.map((scheme) => _SchemeCard(
                scheme: scheme,
                onLoad: () => _loadScheme(scheme),
                onDelete: () =>
                    context.read<CalcManager>().deleteScheme(scheme.id),
              )),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ResultTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.mediumGrey,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SchemeCard extends StatelessWidget {
  final CalcScheme scheme;
  final VoidCallback onLoad;
  final VoidCallback onDelete;

  const _SchemeCard({
    required this.scheme,
    required this.onLoad,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onLoad,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.accentBlue.withValues(alpha: 0.1),
                child: const Icon(Icons.bookmark,
                    color: AppColors.accentBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(scheme.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      '${scheme.unitCount}x · RM ${scheme.equipmentPrice.toStringAsFixed(0)} · '
                      '${scheme.interestRate.toStringAsFixed(2)}% · ${scheme.loanTermMonths}mo',
                      style: const TextStyle(
                          color: AppColors.mediumGrey, fontSize: 12),
                    ),
                    Text(
                      'Monthly: RM ${scheme.monthlyPayment.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: AppColors.accentBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                tooltip: 'Delete scheme',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
