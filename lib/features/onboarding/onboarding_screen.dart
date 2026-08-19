import 'package:flutter/material.dart';

import '../../core/constants.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingContent> _pages = [
    _OnboardingContent(
      icon: Icons.account_balance_outlined,
      color: AppColors.primaryRed,
      title: 'Welcome to SME Financing',
      description:
          'Plan equipment financing with a simple platform designed for Malaysian SMEs.',
    ),
    _OnboardingContent(
      icon: Icons.show_chart,
      color: AppColors.accentBlue,
      title: 'Monitor Interest Rates',
      description:
          'Explore OPR, Base Rate and Lending Rate trends, then set an alert for your target OPR.',
    ),
    _OnboardingContent(
      icon: Icons.assignment_outlined,
      color: AppColors.bankerTeal,
      title: 'Apply for Financing',
      description:
          'Submit an equipment loan application and follow its status. Banker access can review applications.',
    ),
    _OnboardingContent(
      icon: Icons.calculate_outlined,
      color: AppColors.warning,
      title: 'Calculate Your Payments',
      description:
          'Estimate monthly instalments and total repayment, then save financing plans for later.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == _pages.length - 1) {
      widget.onFinished();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onFinished,
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemBuilder: (context, index) => _OnboardingPage(
                  content: _pages[index],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                children: [
                  Semantics(
                    label: 'Page ${_currentPage + 1} of ${_pages.length}',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: index == _currentPage ? 26 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: index == _currentPage
                                ? AppColors.primaryRed
                                : AppColors.lightGrey,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _nextPage,
                      icon: Icon(
                        isLastPage ? Icons.login : Icons.arrow_forward,
                      ),
                      label: Text(isLastPage ? 'Get Started' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingContent content;

  const _OnboardingPage({required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 136,
            height: 136,
            decoration: BoxDecoration(
              color: content.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(content.icon, size: 68, color: content.color),
          ),
          const SizedBox(height: 44),
          Text(
            content.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.darkGrey,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            content.description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.mediumGrey,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingContent {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _OnboardingContent({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
}
