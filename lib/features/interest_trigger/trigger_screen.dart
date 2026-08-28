import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/mock_data.dart';
import 'trigger_manager.dart';

class TriggerScreen extends StatefulWidget {
  const TriggerScreen({super.key});

  @override
  State<TriggerScreen> createState() => _TriggerScreenState();
}

class _TriggerScreenState extends State<TriggerScreen> {
  double _selectedYear = 2024;
  double _currentOPR = 3.00;
  double _currentBaseRate = 6.66;
  double _currentLendingRate = 7.44;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateRates(_selectedYear);
      }
    });
  }

  void _updateRates(double yearDouble) {
    final year = yearDouble.round();
    final data = MockData.getDataByYear(year);
    if (data != null) {
      setState(() {
        _selectedYear = yearDouble;
        _currentOPR = (data['opr'] as num).toDouble();
        _currentBaseRate = (data['baseRate'] as num).toDouble();
        _currentLendingRate = (data['lendingRate'] as num).toDouble();
      });

      final manager = context.read<TriggerManager>();
      final triggered = manager.checkTriggers(_currentOPR, year);
      if (triggered.isNotEmpty) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🔔 Alert: OPR ${_currentOPR.toStringAsFixed(2)}% is at a '
              'historic low — best time to invest in equipment!',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () => _showNotificationInbox(),
            ),
          ),
        );
      }
    }
  }

  void _showNotificationInbox() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer<TriggerManager>(
        builder: (_, manager, _) {
          final notifications = manager.notifications;
          return DraggableScrollableSheet(
            initialChildSize: 0.5,
            maxChildSize: 0.85,
            minChildSize: 0.3,
            expand: false,
            builder: (_, scrollCtrl) => Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.lightGrey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active,
                        color: AppColors.accentBlue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Notification Inbox (${notifications.length})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (notifications.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            manager.clearInbox();
                            Navigator.pop(ctx);
                          },
                          child: const Text('Clear All'),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: notifications.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.notifications_off,
                                size: 48,
                                color: AppColors.lightGrey,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No notifications yet',
                                style: TextStyle(color: AppColors.mediumGrey),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.all(12),
                          itemCount: notifications.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final notification = notifications[index];
                            return ListTile(
                              onTap: () =>
                                  manager.markNotificationRead(notification.id),
                              leading: CircleAvatar(
                                backgroundColor: notification.isRead
                                    ? AppColors.lightGrey.withValues(alpha: 0.3)
                                    : const Color(0xFFE8F5E9),
                                child: Icon(
                                  notification.isRead
                                      ? Icons.notifications_none
                                      : Icons.notifications,
                                  color: notification.isRead
                                      ? AppColors.mediumGrey
                                      : AppColors.success,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                notification.message,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: notification.isRead
                                      ? FontWeight.normal
                                      : FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                _formatNotificationTimestamp(
                                  notification.timestamp,
                                ),
                              ),
                              trailing: IconButton(
                                tooltip: 'Delete notification',
                                onPressed: () =>
                                    manager.deleteNotification(notification.id),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatNotificationTimestamp(DateTime timestamp) {
    final local = timestamp.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }

  void _showAddRuleDialog({TriggerRule? existing}) {
    final oprCtrl = TextEditingController(
      text: existing?.targetOPR.toString() ?? '3.00',
    );
    String selectedEquipment =
        existing?.equipmentType ?? MockData.equipmentTypes.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing != null ? 'Edit Rule' : 'Add Trigger Rule'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: oprCtrl,
                decoration: appInputDecoration(
                  label: 'Target OPR Threshold (%)',
                  hint: 'e.g. 2.75',
                  prefixIcon: Icons.trending_down,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: selectedEquipment,
                decoration: appInputDecoration(
                  label: 'Equipment Type',
                  prefixIcon: Icons.precision_manufacturing,
                ),
                items: MockData.equipmentTypes
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setDialogState(() => selectedEquipment = v);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final opr = double.tryParse(oprCtrl.text.trim());
                if (opr == null) return;

                final manager = context.read<TriggerManager>();

                if (existing != null) {
                  manager.editRule(
                    existing.copyWith(
                      targetOPR: opr,
                      equipmentType: selectedEquipment,
                    ),
                  );
                } else {
                  manager.addRule(
                    TriggerRule(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      targetOPR: opr,
                      equipmentType: selectedEquipment,
                    ),
                  );
                }

                Navigator.pop(ctx);
                manager.checkTriggers(_currentOPR, _selectedYear.round());
              },
              child: Text(existing != null ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<TriggerManager>();
    final rules = manager.rules;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape =
            MediaQuery.orientationOf(context) == Orientation.landscape;

        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.timeline,
                              color: AppColors.primaryRed,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'BNM Interest Rate Timeline',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.darkGrey,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Drag the slider to simulate historical OPR rates from data.gov.my',
                          style: TextStyle(
                            color: AppColors.mediumGrey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 20),

                        _YearSelector(
                          selectedYear: _selectedYear,
                          isLandscape: isLandscape,
                          onChanged: _updateRates,
                        ),
                        const SizedBox(height: 20),

                        Row(
                          children: [
                            Expanded(
                              child: _RateCard(
                                label: 'OPR',
                                value: '${_currentOPR.toStringAsFixed(2)}%',
                                color: AppColors.primaryRed,
                                icon: Icons.show_chart,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _RateCard(
                                label: 'Base Rate',
                                value:
                                    '${_currentBaseRate.toStringAsFixed(2)}%',
                                color: AppColors.accentBlue,
                                icon: Icons.account_balance,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _RateCard(
                                label: 'Lending',
                                value:
                                    '${_currentLendingRate.toStringAsFixed(2)}%',
                                color: AppColors.bankerTeal,
                                icon: Icons.payments,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.insert_chart_outlined,
                              color: AppColors.accentBlue,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Interest Rate Trend (1997–2026)',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.darkGrey,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'OPR · Base Rate · Lending Rate',
                          style: TextStyle(
                            color: AppColors.mediumGrey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),

                        AspectRatio(
                          aspectRatio: isLandscape
                              ? (constraints.maxWidth >= 900 ? 3.4 : 2.7)
                              : 1.55,
                          child: CustomPaint(
                            painter: _RateChartPainter(
                              data: MockData.bnmHistoryData,
                              selectedYear: _selectedYear.round(),
                              oprColor: AppColors.primaryRed,
                              baseRateColor: AppColors.accentBlue,
                              lendingRateColor: AppColors.bankerTeal,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 16,
                          runSpacing: 8,
                          children: const [
                            _LegendDot(
                              color: AppColors.primaryRed,
                              label: 'OPR',
                            ),
                            _LegendDot(
                              color: AppColors.accentBlue,
                              label: 'Base Rate',
                            ),
                            _LegendDot(
                              color: AppColors.bankerTeal,
                              label: 'Lending',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    const SizedBox(width: 16),
                    Icon(Icons.rule, color: AppColors.mediumGrey, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      'Trigger Rules (${rules.length})',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.mediumGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (rules.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 48,
                              color: AppColors.lightGrey,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No trigger rules yet',
                              style: TextStyle(color: AppColors.mediumGrey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap + to add an OPR alert rule',
                              style: TextStyle(
                                color: AppColors.mediumGrey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ...rules.map(
                    (rule) => Dismissible(
                      key: ValueKey(rule.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
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
                      onDismissed: (_) => manager.removeRule(rule.id),
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: rule.isEnabled
                                ? AppColors.success.withValues(alpha: 0.12)
                                : AppColors.lightGrey,
                            child: Icon(
                              Icons.notifications_active,
                              color: rule.isEnabled
                                  ? AppColors.success
                                  : AppColors.mediumGrey,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            rule.equipmentType,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            'Alert when OPR ≤ ${rule.targetOPR.toStringAsFixed(2)}%',
                            style: const TextStyle(
                              color: AppColors.mediumGrey,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                color: AppColors.accentBlue,
                                onPressed: () =>
                                    _showAddRuleDialog(existing: rule),
                                tooltip: 'Edit rule',
                              ),
                              Switch(
                                value: rule.isEnabled,
                                activeThumbColor: AppColors.success,
                                onChanged: (_) => manager.toggleRule(rule.id),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 80),
              ],
            ),

            Positioned(
              bottom: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'inbox',
                    onPressed: _showNotificationInbox,
                    backgroundColor: AppColors.darkGrey,
                    child: Badge(
                      isLabelVisible: manager.unreadCount > 0,
                      label: Text('${manager.unreadCount}'),
                      child: const Icon(
                        Icons.notifications,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton(
                    heroTag: 'addRule',
                    onPressed: () => _showAddRuleDialog(),
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _YearSelector extends StatelessWidget {
  final double selectedYear;
  final bool isLandscape;
  final ValueChanged<double> onChanged;

  const _YearSelector({
    required this.selectedYear,
    required this.isLandscape,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final slider = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.primaryRed,
            inactiveTrackColor: AppColors.primaryRed.withValues(alpha: 0.2),
            thumbColor: AppColors.primaryRed,
            overlayColor: AppColors.primaryRed.withValues(alpha: 0.12),
            valueIndicatorColor: AppColors.primaryRed,
            trackHeight: 6,
          ),
          child: Slider(
            value: selectedYear,
            min: 1997,
            max: 2026,
            divisions: 29,
            label: '${selectedYear.round()}',
            onChanged: onChanged,
          ),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '1997',
              style: TextStyle(fontSize: 11, color: AppColors.mediumGrey),
            ),
            Text(
              '2026',
              style: TextStyle(fontSize: 11, color: AppColors.mediumGrey),
            ),
          ],
        ),
      ],
    );
    final year = Text(
      '${selectedYear.round()}',
      style: TextStyle(
        fontSize: isLandscape ? 38 : 42,
        fontWeight: FontWeight.w800,
        color: AppColors.primaryRed,
        letterSpacing: 2,
      ),
    );

    if (isLandscape) {
      return Row(
        children: [
          year,
          const SizedBox(width: 24),
          Expanded(child: slider),
        ],
      );
    }

    return Column(children: [year, const SizedBox(height: 4), slider]);
  }
}

class _RateCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _RateCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.mediumGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _RateChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final int selectedYear;
  final Color oprColor;
  final Color baseRateColor;
  final Color lendingRateColor;

  _RateChartPainter({
    required this.data,
    required this.selectedYear,
    required this.oprColor,
    required this.baseRateColor,
    required this.lendingRateColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const double leftPad = 36;
    const double rightPad = 12;
    const double topPad = 10;
    const double bottomPad = 28;

    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;

    double minRate = double.infinity;
    double maxRate = double.negativeInfinity;
    for (final d in data) {
      for (final key in ['opr', 'baseRate', 'lendingRate']) {
        final v = (d[key] as num).toDouble();
        if (v < minRate) minRate = v;
        if (v > maxRate) maxRate = v;
      }
    }
    minRate = (minRate - 0.5).clamp(0, double.infinity);
    maxRate = maxRate + 0.5;
    final rateSpan = maxRate - minRate;

    double xFor(int index) => leftPad + (index / (data.length - 1)) * chartW;
    double yFor(double rate) =>
        topPad + chartH - ((rate - minRate) / rateSpan) * chartH;

    final gridPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 0.5;

    final gridSteps = 5;
    for (int i = 0; i <= gridSteps; i++) {
      final rate = minRate + (rateSpan / gridSteps) * i;
      final y = yFor(rate);
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        gridPaint,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: '${rate.toStringAsFixed(1)}%',
          style: const TextStyle(fontSize: 9, color: Color(0xFF9E9E9E)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 4, y - tp.height / 2));
    }

    final yearInterval = (data.length / 6).ceil();
    for (int i = 0; i < data.length; i++) {
      if (i % yearInterval == 0 || i == data.length - 1) {
        final year = data[i]['year'] as int;
        final x = xFor(i);
        final tp = TextPainter(
          text: TextSpan(
            text: '$year',
            style: const TextStyle(fontSize: 9, color: Color(0xFF9E9E9E)),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, size.height - bottomPad + 8));
      }
    }

    int selectedIdx = data.indexWhere((d) => d['year'] == selectedYear);
    if (selectedIdx >= 0) {
      final sx = xFor(selectedIdx);
      final highlightPaint = Paint()
        ..color = oprColor.withValues(alpha: 0.10)
        ..strokeWidth = chartW / data.length
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(sx, topPad),
        Offset(sx, topPad + chartH),
        highlightPaint,
      );

      final linePaint = Paint()
        ..color = oprColor.withValues(alpha: 0.35)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      final dashPath = Path();
      const dashLen = 4.0;
      const gapLen = 3.0;
      double cy = topPad;
      while (cy < topPad + chartH) {
        dashPath.moveTo(sx, cy);
        dashPath.lineTo(sx, (cy + dashLen).clamp(cy, topPad + chartH));
        cy += dashLen + gapLen;
      }
      canvas.drawPath(dashPath, linePaint);
    }

    void drawLine(String key, Color color, {bool fillGradient = false}) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      for (int i = 0; i < data.length; i++) {
        final x = xFor(i);
        final y = yFor((data[i][key] as num).toDouble());
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);

      if (fillGradient) {
        final fillPath = Path.from(path);
        fillPath.lineTo(xFor(data.length - 1), topPad + chartH);
        fillPath.lineTo(xFor(0), topPad + chartH);
        fillPath.close();

        final gradient = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.18),
              color.withValues(alpha: 0.02),
            ],
          ).createShader(Rect.fromLTWH(leftPad, topPad, chartW, chartH));
        canvas.drawPath(fillPath, gradient);
      }

      for (int i = 0; i < data.length; i++) {
        final x = xFor(i);
        final y = yFor((data[i][key] as num).toDouble());
        final isSelected = (data[i]['year'] as int) == selectedYear;
        if (isSelected) {
          canvas.drawCircle(
            Offset(x, y),
            6,
            Paint()..color = color.withValues(alpha: 0.18),
          );
          canvas.drawCircle(Offset(x, y), 4, Paint()..color = Colors.white);
          canvas.drawCircle(Offset(x, y), 3, Paint()..color = color);
        }
      }
    }

    drawLine('lendingRate', lendingRateColor);
    drawLine('baseRate', baseRateColor);
    drawLine('opr', oprColor, fillGradient: true);
  }

  @override
  bool shouldRepaint(covariant _RateChartPainter oldDelegate) {
    return oldDelegate.selectedYear != selectedYear;
  }
}
