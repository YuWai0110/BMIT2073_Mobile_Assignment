import 'package:flutter/material.dart';

class ResponsiveInputDialog extends StatelessWidget {
  final Widget title;
  final Widget content;
  final List<Widget> actions;

  const ResponsiveInputDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final theme = Theme.of(context);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableHeight = (constraints.maxHeight - 32).clamp(
                0.0,
                double.infinity,
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: availableHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Material(
                        color:
                            theme.dialogTheme.backgroundColor ??
                            theme.colorScheme.surfaceContainerHigh,
                        elevation: theme.dialogTheme.elevation ?? 6,
                        shadowColor: theme.dialogTheme.shadowColor,
                        surfaceTintColor: theme.dialogTheme.surfaceTintColor,
                        shape:
                            theme.dialogTheme.shape ??
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DefaultTextStyle(
                                style:
                                    theme.textTheme.headlineSmall ??
                                    const TextStyle(fontSize: 24),
                                child: title,
                              ),
                              const SizedBox(height: 16),
                              content,
                              const SizedBox(height: 20),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Wrap(
                                  alignment: WrapAlignment.end,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: actions,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
