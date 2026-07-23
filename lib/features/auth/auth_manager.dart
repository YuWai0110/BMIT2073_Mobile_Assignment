import 'package:flutter/foundation.dart';

class UserAccount {
  final String id;
  String fullName;
  String email;
  String password;
  String companyName;
  String phone;

  UserAccount({
    required this.id,
    required this.fullName,
    required this.email,
    required this.password,
    this.companyName = '',
    this.phone = '',
  });

  UserAccount copyWith({
    String? id,
    String? fullName,
    String? email,
    String? password,
    String? companyName,
    String? phone,
  }) {
    return UserAccount(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      password: password ?? this.password,
      companyName: companyName ?? this.companyName,
      phone: phone ?? this.phone,
    );
  }

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }
}

class AuthManager extends ChangeNotifier {
  final List<UserAccount> _registeredUsers = [
    UserAccount(
      id: 'demo_user_1',
      fullName: 'Ahmad Bin Hassan',
      email: 'sme@techvision.com',
      password: 'password123',
      companyName: 'TechVision Automation Sdn Bhd',
      phone: '+60-12-345-6789',
    ),
    UserAccount(
      id: 'demo_user_2',
      fullName: 'Lee Wei Ling',
      email: 'demo@sme.my',
      password: 'password123',
      companyName: 'Smart Robotics Industry',
      phone: '+60-16-987-6543',
    ),
  ];

  UserAccount? _currentUser;

  bool _isBanker = false;

  static const String bankerAccessCode = 'BNM2026';

  UserAccount? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isBanker => _isBanker;
  List<UserAccount> get registeredUsers => List.unmodifiable(_registeredUsers);

  String? signUp({
    required String fullName,
    required String email,
    required String password,
    String companyName = '',
    String phone = '',
  }) {
    final exists = _registeredUsers.any(
      (u) => u.email.toLowerCase() == email.toLowerCase(),
    );
    if (exists) {
      return 'An account with this email already exists.';
    }

    final user = UserAccount(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fullName: fullName.trim(),
      email: email.trim().toLowerCase(),
      password: password,
      companyName: companyName.trim(),
      phone: phone.trim(),
    );

    _registeredUsers.add(user);
    _currentUser = user;
    _isBanker = false;
    notifyListeners();
    return null;
  }

  String? login({
    required String email,
    required String password,
  }) {
    final trimmedEmail = email.trim().toLowerCase();

    final index = _registeredUsers.indexWhere(
      (u) => u.email == trimmedEmail,
    );

    if (index == -1) {
      return 'No account found with this email.';
    }

    if (_registeredUsers[index].password != password) {
      return 'Incorrect password.';
    }

    _currentUser = _registeredUsers[index];
    _isBanker = false;
    notifyListeners();
    return null;
  }

  String? bankerLogin(String code) {
    if (code.trim() != bankerAccessCode) {
      return 'Invalid access code.';
    }

    _currentUser = UserAccount(
      id: 'banker_001',
      fullName: 'BNM Banker',
      email: 'banker@bnm.gov.my',
      password: '',
      companyName: 'Bank Negara Malaysia',
      phone: '+60-3-2698-8044',
    );
    _isBanker = true;
    notifyListeners();
    return null;
  }

  void logout() {
    _currentUser = null;
    _isBanker = false;
    notifyListeners();
  }

  void updateProfile({
    String? fullName,
    String? companyName,
    String? phone,
  }) {
    if (_currentUser == null) return;

    if (fullName != null) _currentUser!.fullName = fullName.trim();
    if (companyName != null) _currentUser!.companyName = companyName.trim();
    if (phone != null) _currentUser!.phone = phone.trim();

    if (!_isBanker) {
      final index = _registeredUsers.indexWhere(
        (u) => u.id == _currentUser!.id,
      );
      if (index != -1) {
        _registeredUsers[index] = _currentUser!;
      }
    }

    notifyListeners();
  }

  String? resetPassword({
    required String email,
    required String newPassword,
  }) {
    final trimmedEmail = email.trim().toLowerCase();

    final index = _registeredUsers.indexWhere(
      (u) => u.email == trimmedEmail,
    );

    if (index == -1) {
      return 'No account found with this email.';
    }

    _registeredUsers[index].password = newPassword;
    notifyListeners();
    return null;
  }
}
