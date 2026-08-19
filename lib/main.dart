import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'features/auth/auth_manager.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/profile_screen.dart';
import 'features/loan_approval/loan_manager.dart';
import 'features/loan_approval/loan_screen.dart';
import 'features/calculator_roi/calc_manager.dart';
import 'features/calculator_roi/calc_screen.dart';
import 'features/interest_trigger/trigger_manager.dart';
import 'features/interest_trigger/trigger_screen.dart';
import 'features/onboarding/onboarding_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthManager()),
        ChangeNotifierProvider(create: (_) => LoanManager()),
        ChangeNotifierProvider(create: (_) => CalcManager()),
        ChangeNotifierProvider(create: (_) => TriggerManager()),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BNM SME Financing Platform',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const _AppEntry(),
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _hasCompletedOnboarding = false;

  @override
  Widget build(BuildContext context) {
    if (!_hasCompletedOnboarding) {
      return OnboardingScreen(
        onFinished: () => setState(() => _hasCompletedOnboarding = true),
      );
    }

    return Consumer<AuthManager>(
      builder: (context, auth, _) {
        if (!auth.isLoggedIn) {
          return const LoginScreen();
        }
        return const _HomeShell();
      },
    );
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell();

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _currentIndex = 0;

  static const List<String> _tabTitles = [
    'Interest Rate Monitor',
    'Loan Approval',
    'ROI Calculator',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthManager>();
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(_tabTitles[_currentIndex]),
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: CircleAvatar(
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Icon(
              auth.isBanker ? Icons.account_balance : Icons.business,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        actions: [
          if (user != null) ...[
            Center(
              child: Text(
                auth.isBanker ? 'Banker' : user.fullName.split(' ').first,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.white70,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _currentIndex = 3),
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: auth.isBanker
                      ? AppColors.bankerTeal
                      : Colors.white.withValues(alpha: 0.25),
                  child: Text(
                    user.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),

      body: IndexedStack(
        index: _currentIndex,
        children: [
          const TriggerScreen(),
          LoanScreen(isBanker: auth.isBanker),
          const CalcScreen(),
          const ProfileScreen(),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.timeline),
            activeIcon: Icon(Icons.timeline, size: 28),
            label: 'Rates',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment, size: 28),
            label: 'Loans',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calculate_outlined),
            activeIcon: Icon(Icons.calculate, size: 28),
            label: 'Calculator',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person, size: 28),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
