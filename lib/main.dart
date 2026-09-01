import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants.dart';
import 'features/auth/auth_manager.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/profile_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/loan_approval/loan_manager.dart';
import 'features/loan_approval/loan_screen.dart';
import 'features/calculator_roi/calc_manager.dart';
import 'features/calculator_roi/calc_screen.dart';
import 'features/interest_trigger/trigger_manager.dart';
import 'features/interest_trigger/trigger_screen.dart';
import 'services/database/database_service.dart';
import 'services/supabase/auth_repository.dart';
import 'services/supabase/loan_repository.dart';
import 'services/supabase/profile_repository.dart';
import 'services/supabase/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  final supabaseUrl = dotenv.get('SUPABASE_URL');
  final supabaseKey = dotenv.get('SUPABASE_ANON_KEY');
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);

  final database = DatabaseService.instance;
  await database.initialize();

  final calcManager = CalcManager(database: database);
  final triggerManager = TriggerManager(database: database);
  await Future.wait([calcManager.initialize(), triggerManager.initialize()]);

  final supabaseService = SupabaseService(Supabase.instance.client);
  final loanManager = LoanManager(LoanRepository(supabaseService));
  final authManager = AuthManager(
    AuthRepository(supabaseService),
    ProfileRepository(supabaseService),
    onAuthenticationChanged: (user) async {
      await Future.wait([
        loanManager.loadApplications(),
        triggerManager.setUser(user?.id),
      ]);
    },
  );
  await authManager.initialize();
  await Future.wait([
    loanManager.initialize(),
    triggerManager.setUser(authManager.currentUser?.id),
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authManager),
        ChangeNotifierProvider.value(value: loanManager),
        ChangeNotifierProvider.value(value: calcManager),
        ChangeNotifierProvider.value(value: triggerManager),
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final useNavigationRail = isLandscape && screenWidth >= 700;
    final showGreeting = screenWidth >= 520;

    final pages = IndexedStack(
      index: _currentIndex,
      children: [
        const TriggerScreen(),
        LoanScreen(isBanker: auth.isBanker),
        const CalcScreen(),
        const ProfileScreen(),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tabTitles[_currentIndex],
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
            if (showGreeting)
              Center(
                child: Text(
                  auth.isBanker ? 'Banker' : user.fullName.split(' ').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ),
            SizedBox(width: showGreeting ? 8 : 4),
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

      body: useNavigationRail
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) {
                    setState(() => _currentIndex = index);
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.timeline),
                      selectedIcon: Icon(Icons.timeline),
                      label: Text('Rates'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.assignment_outlined),
                      selectedIcon: Icon(Icons.assignment),
                      label: Text('Loans'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.calculate_outlined),
                      selectedIcon: Icon(Icons.calculate),
                      label: Text('Calculator'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: Text('Profile'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: pages),
              ],
            )
          : pages,
      bottomNavigationBar: useNavigationRail
          ? null
          : BottomNavigationBar(
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
