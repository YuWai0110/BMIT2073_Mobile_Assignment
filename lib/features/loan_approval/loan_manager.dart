import 'package:flutter/foundation.dart';

import '../../services/supabase/loan_repository.dart';
import '../../services/supabase/supabase_service.dart';
import '../../core/mock_data.dart';

enum LoanStatus {
  pending('Pending', '⏳', 'pending'),
  approved('Approved', '✅', 'approved'),
  notApproved('Not Approved', '❌', 'rejected');

  final String label;
  final String icon;
  final String databaseValue;
  const LoanStatus(this.label, this.icon, this.databaseValue);

  static LoanStatus fromDatabase(String value) {
    return LoanStatus.values.firstWhere(
      (status) => status.databaseValue == value,
      orElse: () => LoanStatus.pending,
    );
  }
}

class LoanRequest {
  final String id;
  final String? userId;
  final String companyName;
  final String equipmentName;
  final double loanAmount;
  final double interestRate;
  final int repaymentYears;
  final DateTime createdAt;
  LoanStatus status;

  LoanRequest({
    required this.id,
    this.userId,
    required this.companyName,
    required this.equipmentName,
    required this.loanAmount,
    required this.interestRate,
    this.repaymentYears = 5,
    DateTime? createdAt,
    this.status = LoanStatus.pending,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  factory LoanRequest.fromMap(Map<String, dynamic> map) {
    return LoanRequest(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      companyName: map['company_name'] as String,
      equipmentName: map['equipment_name'] as String,
      loanAmount: (map['amount'] as num).toDouble(),
      interestRate: (map['interest_rate'] as num).toDouble(),
      repaymentYears: (map['repayment_years'] as num).toInt(),
      status: LoanStatus.fromDatabase(map['status'] as String),
      createdAt: DateTime.parse(map['created_at'] as String).toUtc(),
    );
  }

  Map<String, dynamic> toInsertMap(String ownerId) {
    return {
      'user_id': ownerId,
      'company_name': companyName,
      'equipment_name': equipmentName,
      'amount': loanAmount,
      'interest_rate': interestRate,
      'repayment_years': repaymentYears,
      'status': LoanStatus.pending.databaseValue,
    };
  }

  LoanRequest copyWith({
    String? id,
    String? userId,
    String? companyName,
    String? equipmentName,
    double? loanAmount,
    double? interestRate,
    int? repaymentYears,
    DateTime? createdAt,
    LoanStatus? status,
  }) {
    return LoanRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      companyName: companyName ?? this.companyName,
      equipmentName: equipmentName ?? this.equipmentName,
      loanAmount: loanAmount ?? this.loanAmount,
      interestRate: interestRate ?? this.interestRate,
      repaymentYears: repaymentYears ?? this.repaymentYears,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }
}

class LoanManager extends ChangeNotifier {
  final LoanRepository? _repository;
  final List<LoanRequest> _requests = [];
  bool _isLoading = false;
  String? _lastError;
  String _formCompanyName = '';
  String _formLoanAmount = '';
  String _formEquipmentType = MockData.equipmentTypes.first;
  double _formInterestRate = 4.5;
  int _formRepaymentYears = 5;
  bool _formValidationVisible = false;

  LoanManager([this._repository]);

  List<LoanRequest> get allRequests => List.unmodifiable(_requests);
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  String get formCompanyName => _formCompanyName;
  String get formLoanAmount => _formLoanAmount;
  String get formEquipmentType => _formEquipmentType;
  double get formInterestRate => _formInterestRate;
  int get formRepaymentYears => _formRepaymentYears;
  bool get formValidationVisible => _formValidationVisible;

  void updateFormCompanyName(String value) {
    if (_formCompanyName == value) return;
    _formCompanyName = value;
    notifyListeners();
  }

  void updateFormLoanAmount(String value) {
    if (_formLoanAmount == value) return;
    _formLoanAmount = value;
    notifyListeners();
  }

  void updateFormEquipmentType(String value) {
    if (_formEquipmentType == value) return;
    _formEquipmentType = value;
    notifyListeners();
  }

  void updateFormInterestRate(double value) {
    if (_formInterestRate == value) return;
    _formInterestRate = value;
    notifyListeners();
  }

  void updateFormRepaymentYears(int value) {
    if (_formRepaymentYears == value) return;
    _formRepaymentYears = value;
    notifyListeners();
  }

  void showFormValidation() {
    if (_formValidationVisible) return;
    _formValidationVisible = true;
    notifyListeners();
  }

  void clearLoanForm() {
    _formCompanyName = '';
    _formLoanAmount = '';
    _formValidationVisible = false;
    notifyListeners();
  }

  Future<void> initialize() => loadApplications();

  Future<void> loadApplications() async {
    final repository = _repository;
    if (repository == null) return;
    if (repository.currentUserId == null) {
      _requests.clear();
      _lastError = null;
      notifyListeners();
      return;
    }

    _setLoading(true);
    try {
      final rows = await repository.findVisibleApplications();
      _requests
        ..clear()
        ..addAll(rows.map(LoanRequest.fromMap));
      _lastError = null;
    } catch (error) {
      _lastError = _messageFor(error);
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> addLoanRequest(LoanRequest request) async {
    final repository = _repository;
    if (repository == null) {
      _requests.add(request);
      notifyListeners();
      return null;
    }

    final ownerId = repository.currentUserId;
    if (ownerId == null) return 'Please sign in before applying.';
    try {
      final row = await repository.create(request.toInsertMap(ownerId));
      _requests.add(LoanRequest.fromMap(row));
      _lastError = null;
      notifyListeners();
      return null;
    } catch (error) {
      _lastError = _messageFor(error);
      notifyListeners();
      return _lastError;
    }
  }

  Future<String?> updateStatus(String id, LoanStatus newStatus) async {
    final repository = _repository;
    final index = _requests.indexWhere((request) => request.id == id);
    if (index == -1) return 'Loan application was not found.';

    if (repository == null) {
      _requests[index].status = newStatus;
      notifyListeners();
      return null;
    }

    try {
      final row = await repository.updateStatus(id, newStatus.databaseValue);
      _requests[index] = LoanRequest.fromMap(row);
      _lastError = null;
      notifyListeners();
      return null;
    } catch (error) {
      _lastError = _messageFor(error);
      notifyListeners();
      return _lastError;
    }
  }

  Future<String?> deleteRequest(String id) async {
    final repository = _repository;
    final index = _requests.indexWhere((request) => request.id == id);
    if (index == -1) return 'Loan application was not found.';
    final removed = _requests.removeAt(index);
    notifyListeners();

    if (repository == null) {
      return null;
    }

    try {
      await repository.delete(id);
      _lastError = null;
      return null;
    } catch (error) {
      _requests.insert(index.clamp(0, _requests.length), removed);
      _lastError = _messageFor(error);
      notifyListeners();
      return _lastError;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _messageFor(Object error) {
    return friendlySupabaseError(
      error,
      fallback: 'Unable to update loan applications. Please try again.',
    );
  }
}
