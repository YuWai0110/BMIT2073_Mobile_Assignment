import 'package:flutter/foundation.dart';

import '../../services/supabase/loan_repository.dart';
import '../../services/supabase/supabase_service.dart';
import '../../core/mock_data.dart';
import 'loan_validators.dart';

enum LoanFilter { all, pending, approved, rejected }

enum LoanStatus {
  pending('Pending', '⏳', 'pending'),
  approved('Approved', '✅', 'approved'),
  notApproved('Rejected', '❌', 'rejected');

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
  final DateTime submittedAt;
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
    DateTime? submittedAt,
    this.status = LoanStatus.pending,
  }) : createdAt = createdAt ?? DateTime.now().toUtc(),
       submittedAt = submittedAt ?? createdAt ?? DateTime.now().toUtc();

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
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '')?.toUtc(),
      submittedAt: DateTime.tryParse(
        (map['submitted_at'] ?? map['created_at']) as String? ?? '',
      )?.toUtc(),
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
    DateTime? submittedAt,
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
      submittedAt: submittedAt ?? this.submittedAt,
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
  String? _editingId;
  LoanFilter _filter = LoanFilter.all;
  bool _isSaving = false;
  String? _ownerId;
  int _sessionVersion = 0;
  bool _disposed = false;

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
  bool get isSaving => _isSaving;
  String? get editingId => _editingId;
  bool get isEditing => _editingId != null;
  LoanFilter get filter => _filter;
  bool get isFormValid =>
      validateLoanCompany(_formCompanyName) == null &&
      validateLoanAmount(_formLoanAmount) == null;
  List<LoanRequest> get filteredRequests => List.unmodifiable(
    _requests.where(
      (r) =>
          _filter == LoanFilter.all || r.status.databaseValue == _filter.name,
    ),
  );

  void setFilter(LoanFilter value) {
    _filter = value;
    notifyListeners();
  }

  void setUser(String? id) {
    if (_ownerId == id) return;
    _ownerId = id;
    _sessionVersion++;
    _requests.clear();
    _filter = LoanFilter.all;
    _isSaving = false;
    _isLoading = false;
    _lastError = null;
    clearLoanForm();
  }

  String? startEditing(String id) {
    if (_isSaving) return 'Please wait for the current request.';
    final matches = _requests.where((r) => r.id == id);
    if (matches.isEmpty) return 'Loan application was not found.';
    final request = matches.first;
    if (request.status != LoanStatus.pending) {
      return 'Only pending applications can be edited.';
    }
    _editingId = id;
    _formCompanyName = request.companyName;
    _formEquipmentType = request.equipmentName;
    _formLoanAmount = request.loanAmount.toStringAsFixed(2);
    _formInterestRate = request.interestRate;
    _formRepaymentYears = request.repaymentYears;
    _formValidationVisible = true;
    notifyListeners();
    return null;
  }

  Future<String?> saveForm() async {
    if (_isSaving) return 'Please wait for the current request.';
    showFormValidation();
    if (!isFormValid) return 'Please check the application details.';
    final id = _editingId;
    final version = _sessionVersion;
    _isSaving = true;
    notifyListeners();
    final request = LoanRequest(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      companyName: _formCompanyName.trim(),
      equipmentName: _formEquipmentType,
      loanAmount: parseLoanAmountCents(_formLoanAmount)! / 100,
      interestRate: _formInterestRate,
      repaymentYears: _formRepaymentYears,
    );
    try {
      final error = id == null
          ? await addLoanRequest(request)
          : await updateApplication(request);
      if (!_disposed && version == _sessionVersion && error == null) {
        clearLoanForm();
      }
      return error;
    } finally {
      if (!_disposed && version == _sessionVersion) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  Future<String?> updateApplication(LoanRequest request) async {
    final version = _sessionVersion;
    try {
      final repository = _repository;
      if (repository != null) {
        await repository.updateApplication(request.id, {
          'p_company_name': request.companyName,
          'p_equipment_name': request.equipmentName,
          'p_amount': request.loanAmount.toStringAsFixed(2),
          'p_interest_rate': request.interestRate,
          'p_repayment_years': request.repaymentYears,
        });
        if (!_disposed && version == _sessionVersion) {
          await loadApplications(showLoading: false);
        }
      } else {
        final index = _requests.indexWhere((r) => r.id == request.id);
        if (index < 0) return 'Loan application was not found.';
        final current = _requests[index];
        if (current.status != LoanStatus.pending) {
          return 'Only pending applications can be edited.';
        }
        _requests[index] = request.copyWith(
          userId: current.userId,
          createdAt: current.createdAt,
          submittedAt: current.submittedAt,
        );
        notifyListeners();
      }
      return null;
    } catch (error) {
      if (!_disposed && version == _sessionVersion) {
        await loadApplications(showLoading: false);
      }
      return _messageFor(error);
    }
  }

  Future<String?> deletePending(String id) async {
    if (_isSaving) return 'Please wait for the current request.';
    final version = _sessionVersion;
    _isSaving = true;
    notifyListeners();
    try {
      final repository = _repository;
      if (repository == null) {
        final matches = _requests.where((r) => r.id == id);
        if (matches.isEmpty) return 'Loan application was not found.';
        if (matches.first.status != LoanStatus.pending) {
          return 'Only pending applications can be deleted.';
        }
        _requests.removeWhere((r) => r.id == id);
      } else {
        await repository.deletePending(id);
        if (!_disposed && version == _sessionVersion) {
          await loadApplications(showLoading: false);
        }
      }
      if (!_disposed && version == _sessionVersion && _editingId == id) {
        clearLoanForm();
      }
      return null;
    } catch (error) {
      if (!_disposed && version == _sessionVersion) {
        await loadApplications(showLoading: false);
      }
      return _messageFor(error);
    } finally {
      if (!_disposed && version == _sessionVersion) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  void updateFormCompanyName(String value) {
    if (_formCompanyName == value) return;
    _formCompanyName = value;
    _formValidationVisible = true;
    notifyListeners();
  }

  void updateFormLoanAmount(String value) {
    if (_formLoanAmount == value) return;
    _formLoanAmount = value;
    _formValidationVisible = true;
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
    _editingId = null;
    _formEquipmentType = MockData.equipmentTypes.first;
    _formInterestRate = 4.5;
    _formRepaymentYears = 5;
    _formCompanyName = '';
    _formLoanAmount = '';
    _formValidationVisible = false;
    notifyListeners();
  }

  Future<void> initialize() => loadApplications();

  Future<void> loadApplications({bool showLoading = true}) async {
    final version = _sessionVersion;
    final repository = _repository;
    if (repository == null) return;
    if (repository.currentUserId == null) {
      _requests.clear();
      _lastError = null;
      notifyListeners();
      return;
    }

    if (showLoading) _setLoading(true);
    try {
      final rows = await repository.findVisibleApplications();
      if (_disposed || version != _sessionVersion) return;
      _requests
        ..clear()
        ..addAll(rows.map(LoanRequest.fromMap));
      _lastError = null;
    } catch (error) {
      if (_disposed || version != _sessionVersion) return;
      _lastError = _messageFor(error);
    } finally {
      if (!_disposed && version == _sessionVersion) {
        if (showLoading) {
          _setLoading(false);
        } else {
          notifyListeners();
        }
      }
    }
  }

  Future<String?> addLoanRequest(LoanRequest request) async {
    final version = _sessionVersion;
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
      if (_disposed || version != _sessionVersion) return null;
      _requests.add(LoanRequest.fromMap(row));
      _lastError = null;
      notifyListeners();
      await loadApplications(showLoading: false);
      return null;
    } catch (error) {
      if (_disposed || version != _sessionVersion) return _messageFor(error);
      _lastError = _messageFor(error);
      notifyListeners();
      return _lastError;
    }
  }

  Future<String?> updateStatus(String id, LoanStatus newStatus) async {
    final version = _sessionVersion;
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
      if (_disposed || version != _sessionVersion) return null;
      final currentIndex = _requests.indexWhere((r) => r.id == id);
      if (currentIndex >= 0) _requests[currentIndex] = LoanRequest.fromMap(row);
      _lastError = null;
      notifyListeners();
      await loadApplications(showLoading: false);
      return null;
    } catch (error) {
      if (_disposed || version != _sessionVersion) return _messageFor(error);
      _lastError = _messageFor(error);
      notifyListeners();
      return _lastError;
    }
  }

  Future<String?> deleteRequest(String id) => deletePending(id);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _messageFor(Object error) {
    if (error is LoanOperationException) return error.message;
    return friendlySupabaseError(
      error,
      fallback: 'Unable to update loan applications. Please try again.',
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
