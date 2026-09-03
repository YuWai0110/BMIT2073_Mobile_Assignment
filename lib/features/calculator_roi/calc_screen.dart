import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/mock_data.dart';
import '../../core/responsive_input_dialog.dart';
import '../ai/ai_manager.dart';
import '../ai/models/ai_recommendation.dart';
import 'ai_recommendation_card.dart';
import 'calc_manager.dart';

class CalcScreen extends StatefulWidget {
  const CalcScreen({super.key});

  @override
  State<CalcScreen> createState() => _CalcScreenState();
}

class _CalcScreenState extends State<CalcScreen> {
  final _priceCtrl = TextEditingController(text: '0');
  final _unitCtrl = TextEditingController(text: '0');
  double _interestRate = 4.5;
  int _loanTermMonths = 36;
  String? _editingId;
  String? _editingTitle;

  double _monthlyPayment = 0;
  double _totalPayment = 0;
  double _totalInterest = 0;

  static const List<int> _termOptions = [
    12,
    24,
    36,
    48,
    60,
    72,
    84,
    96,
    108,
    120,
    132,
    144,
    156,
    168,
    180,
  ];

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
    final units = int.tryParse(_unitCtrl.text) ?? 0;
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

  void _onCalculatorInputChanged() {
    context.read<AiManager?>()?.clearRecommendation();
    _recalculate();
  }

  AiAdvisorInput _buildAiInput() {
    final equipmentPrice = double.tryParse(_priceCtrl.text) ?? 0;
    final quantity = int.tryParse(_unitCtrl.text) ?? 0;
    final currentOpr = MockData.getDataByYear(2024)?['opr'];

    return AiAdvisorInput(
      equipmentName: _editingTitle ?? 'Automation equipment financing',
      equipmentPrice: equipmentPrice,
      quantity: quantity,
      loanAmount: equipmentPrice * quantity,
      interestRate: _interestRate,
      repaymentYears: _loanTermMonths / 12,
      monthlyEmi: _monthlyPayment,
      currentOpr: currentOpr is num ? currentOpr.toDouble() : 0,
    );
  }

  bool _hasValidCalculatorInput(AiAdvisorInput input) {
    return input.equipmentPrice > 0 &&
        input.quantity > 0 &&
        input.interestRate >= 0 &&
        input.interestRate <= 20;
  }

  Future<void> _generateAiAdvice() async {
    final input = _buildAiInput();
    if (!_hasValidCalculatorInput(input)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Enter a price above RM 0, a quantity above 0, and an interest rate from 0% to 20%.',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final manager = context.read<AiManager?>();
    if (manager == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('AI advice is unavailable right now.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    await manager.generateAdvice(input);
    if (!mounted || manager.errorMessage == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(manager.errorMessage!),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _saveScheme() async {
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final units = int.tryParse(_unitCtrl.text) ?? 0;

    if (price <= 0 || units <= 0 || _interestRate < 0 || _interestRate > 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Enter a price above RM 0, a quantity above 0, and an interest rate from 0% to 20%.',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final editingId = _editingId;
    final isEditing = editingId != null;
    final title = await showDialog<String>(
      context: context,
      useSafeArea: false,
      builder: (_) => _SaveSchemeDialog(isEditing: isEditing),
    );

    if (!mounted || title == null) return;

    final manager = context.read<CalcManager>();
    final scheme = CalcScheme(
      id: editingId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      equipmentPrice: price,
      unitCount: units,
      loanTermMonths: _loanTermMonths,
      interestRate: _interestRate,
      monthlyPayment: _monthlyPayment,
      totalPayment: _totalPayment,
    );

    if (isEditing) {
      manager.updateScheme(scheme);
      setState(() {
        _editingId = null;
        _editingTitle = null;
      });
    } else {
      manager.saveScheme(scheme);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEditing ? '✅ Scheme updated!' : '✅ Scheme saved!'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _loadScheme(CalcScheme scheme) {
    setState(() {
      _editingId = scheme.id;
      _editingTitle = scheme.title;
      _priceCtrl.text = scheme.equipmentPrice.toStringAsFixed(0);
      _unitCtrl.text = scheme.unitCount.toString();
      _interestRate = scheme.interestRate;
      _loanTermMonths = scheme.loanTermMonths;
    });
    _recalculate();
    context.read<AiManager?>()?.clearRecommendation();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📋 Loaded "${scheme.title}" — edit and save to update'),
        backgroundColor: AppColors.accentBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildInputCard(BuildContext context) {
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
                  Icons.calculate_outlined,
                  color: AppColors.accentBlue,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ROI Calculator',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkGrey,
                    ),
                  ),
                ),
                if (_editingId != null)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _editingId = null;
                        _editingTitle = null;
                      });
                      _priceCtrl.text = '0';
                      _unitCtrl.text = '0';
                      _interestRate = 4.5;
                      _loanTermMonths = 36;
                      _onCalculatorInputChanged();
                    },
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear Edit'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: false,
              ),
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (oldValue, newValue) =>
                      RegExp(r'^\d*\.?\d{0,2}$').hasMatch(newValue.text)
                      ? newValue
                      : oldValue,
                ),
              ],
              onChanged: (_) => _onCalculatorInputChanged(),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _unitCtrl,
              decoration: appInputDecoration(
                label: 'Quantity (Units)',
                hint: 'e.g. 3',
                prefixIcon: Icons.inventory_2_outlined,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                signed: false,
              ),
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (oldValue, newValue) =>
                      RegExp(r'^\d*$').hasMatch(newValue.text)
                      ? newValue
                      : oldValue,
                ),
              ],
              onChanged: (_) => _onCalculatorInputChanged(),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(
                  Icons.percent,
                  size: 18,
                  color: AppColors.mediumGrey,
                ),
                Text(
                  'Annual Interest Rate: ${_interestRate.toStringAsFixed(2)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkGrey,
                  ),
                ),
              ],
            ),
            Slider(
              value: _interestRate,
              min: 0,
              max: 20,
              divisions: 80,
              activeColor: AppColors.accentBlue,
              label: '${_interestRate.toStringAsFixed(2)}%',
              onChanged: (v) {
                setState(() => _interestRate = v);
                _onCalculatorInputChanged();
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _loanTermMonths,
              isExpanded: true,
              menuMaxHeight: 240,
              decoration: appInputDecoration(
                label: 'Loan Term',
                prefixIcon: Icons.calendar_month,
              ),
              items: _termOptions
                  .map(
                    (m) => DropdownMenuItem(
                      value: m,
                      child: Text(
                        '$m months (${m ~/ 12} yr${m >= 24 ? "s" : ""})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _loanTermMonths = v);
                  _onCalculatorInputChanged();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          color: AppColors.accentBlue.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stackPrimaryResults = constraints.maxWidth < 420;
                final monthly = _ResultTile(
                  label: 'Monthly Payment',
                  value: 'RM ${_monthlyPayment.toStringAsFixed(2)}',
                  icon: Icons.today,
                  color: AppColors.accentBlue,
                );
                final repayment = _ResultTile(
                  label: 'Total Repayment',
                  value: 'RM ${_totalPayment.toStringAsFixed(2)}',
                  icon: Icons.account_balance_wallet,
                  color: AppColors.primaryRed,
                );

                return Column(
                  children: [
                    Text(
                      'Calculation Results',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.accentBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (stackPrimaryResults) ...[
                      monthly,
                      const SizedBox(height: 12),
                      repayment,
                    ] else
                      Row(
                        children: [
                          Expanded(child: monthly),
                          const SizedBox(width: 12),
                          Expanded(child: repayment),
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
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildAiAdvisor(context),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _saveScheme,
          icon: Icon(_editingId != null ? Icons.save : Icons.bookmark_add),
          label: Text(
            _editingId != null ? 'Update Saved Scheme' : 'Save This Scheme',
          ),
        ),
      ],
    );
  }

  Widget _buildAiAdvisor(BuildContext context) {
    final manager = context.watch<AiManager?>();
    final recommendation = manager?.recommendation;

    return Card(
      margin: EdgeInsets.zero,
      color: AppColors.primaryRed.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: AppColors.primaryRed,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI Financing Advisor',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkGrey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Get a financing recommendation based on your current calculation.',
              style: TextStyle(color: AppColors.mediumGrey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (manager?.isLoading ?? false)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (recommendation != null)
              AiRecommendationCard(recommendation: recommendation)
            else
              ElevatedButton.icon(
                onPressed: manager == null ? null : _generateAiAdvice,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate AI Advice'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedSchemes(BuildContext context, List<CalcScheme> schemes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.bookmarks_outlined,
              color: AppColors.mediumGrey,
              size: 20,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Saved Schemes (${schemes.length})',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.mediumGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (schemes.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.bookmark_border,
                      size: 48,
                      color: AppColors.lightGrey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No saved schemes yet',
                      style: TextStyle(color: AppColors.mediumGrey),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...schemes.reversed.map(
            (scheme) => _SchemeCard(
              scheme: scheme,
              onLoad: () => _loadScheme(scheme),
              onDelete: () =>
                  context.read<CalcManager>().deleteScheme(scheme.id),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final schemes = context.watch<CalcManager>().schemes;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape =
            MediaQuery.orientationOf(context) == Orientation.landscape;
        final useTwoPane = isLandscape && constraints.maxWidth >= 700;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (useTwoPane)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: _buildInputCard(context)),
                    const SizedBox(width: 16),
                    Expanded(flex: 6, child: _buildResults(context)),
                  ],
                )
              else ...[
                _buildInputCard(context),
                const SizedBox(height: 12),
                _buildResults(context),
              ],
              const SizedBox(height: 24),
              _buildSavedSchemes(context, schemes),
            ],
          ),
        );
      },
    );
  }
}

class _SaveSchemeDialog extends StatefulWidget {
  final bool isEditing;

  const _SaveSchemeDialog({required this.isEditing});

  @override
  State<_SaveSchemeDialog> createState() => _SaveSchemeDialogState();
}

class _SaveSchemeDialogState extends State<_SaveSchemeDialog> {
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveInputDialog(
      title: Text(widget.isEditing ? 'Update Scheme' : 'Save Scheme'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            focusNode: _titleFocusNode,
            autofocus: true,
            decoration: appInputDecoration(
              label: 'Scheme Name',
              hint: 'e.g. 2026 Factory-A Robotic Arm Plan',
              prefixIcon: Icons.bookmark_border,
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(widget.isEditing ? 'Update' : 'Save'),
        ),
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
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
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
                child: const Icon(
                  Icons.bookmark,
                  color: AppColors.accentBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scheme.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${scheme.unitCount}x · RM ${scheme.equipmentPrice.toStringAsFixed(0)} · '
                      '${scheme.interestRate.toStringAsFixed(2)}% · ${scheme.loanTermMonths}mo',
                      style: const TextStyle(
                        color: AppColors.mediumGrey,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Monthly: RM ${scheme.monthlyPayment.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.accentBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
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
