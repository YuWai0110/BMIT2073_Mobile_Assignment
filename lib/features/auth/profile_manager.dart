import 'package:flutter/widgets.dart';

import 'auth_manager.dart';

class ProfileManager extends ChangeNotifier {
  ProfileManager(this._auth) {
    _syncUser();
    _auth.addListener(_syncUser);
  }

  final AuthManager _auth;
  String? _userId;
  bool _disposed = false;
  bool isEditing = false;
  bool isSaving = false;
  TextEditingValue fullName = TextEditingValue.empty;
  TextEditingValue company = TextEditingValue.empty;
  TextEditingValue phone = TextEditingValue.empty;

  static String? validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Please enter your full name.';
    if (text.characters.length > 30) {
      return 'Full name must be 30 characters or fewer.';
    }
    return null;
  }

  static String? validateCompany(String? value) {
    if ((value?.trim().characters.length ?? 0) > 50) {
      return 'Company must be 50 characters or fewer.';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final compact = text.replaceAll(RegExp(r'[-\s]'), '');
    final local = compact.startsWith('+60')
        ? '0${compact.substring(3)}'
        : compact;
    if (!RegExp(r'^0[1-9][0-9]{8,9}$').hasMatch(local)) {
      return 'Please enter a valid Malaysian phone number.';
    }
    return null;
  }

  bool get isValid =>
      validateName(fullName.text) == null &&
      validateCompany(company.text) == null &&
      validatePhone(phone.text) == null;

  void _syncUser() {
    final user = _auth.currentUser;
    if (_userId == user?.id && isEditing) return;
    if (_userId != user?.id) {
      isEditing = false;
      isSaving = false;
    }
    _userId = user?.id;
    fullName = TextEditingValue(text: user?.fullName ?? '');
    company = TextEditingValue(text: user?.companyName ?? '');
    phone = TextEditingValue(text: user?.phone ?? '');
    notifyListeners();
  }

  void startEditing() {
    if (_userId == null) return;
    isEditing = true;
    notifyListeners();
  }

  void updateDraft({
    TextEditingValue? name,
    TextEditingValue? companyValue,
    TextEditingValue? phoneValue,
  }) {
    if (isSaving) return;
    fullName = name ?? fullName;
    company = companyValue ?? company;
    phone = phoneValue ?? phone;
    notifyListeners();
  }

  Future<String?> save() async {
    if (!isEditing || !isValid || isSaving) {
      return 'Please check your profile details.';
    }
    final owner = _userId;
    isSaving = true;
    notifyListeners();
    final error = await _auth.updateProfile(
      fullName: fullName.text,
      companyName: company.text,
      phone: phone.text,
    );
    if (_disposed || _userId != owner) return error;
    isSaving = false;
    if (error == null) {
      isEditing = false;
      _syncUser();
    } else {
      notifyListeners();
    }
    return error;
  }

  @override
  void dispose() {
    _disposed = true;
    _auth.removeListener(_syncUser);
    super.dispose();
  }
}
