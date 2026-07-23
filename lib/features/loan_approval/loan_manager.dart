import 'package:flutter/foundation.dart';

enum LoanStatus {
  pending('Pending', '⏳'),
  approved('Approved', '✅'),
  notApproved('Not Approved', '❌');

  final String label;
  final String icon;
  const LoanStatus(this.label, this.icon);
}

class LoanRequest {
  final String id;
  final String companyName;
  final String equipmentName;
  final double loanAmount;
  final double interestRate;
  LoanStatus status;

  LoanRequest({
    required this.id,
    required this.companyName,
    required this.equipmentName,
    required this.loanAmount,
    required this.interestRate,
    this.status = LoanStatus.pending,
  });

  LoanRequest copyWith({
    String? id,
    String? companyName,
    String? equipmentName,
    double? loanAmount,
    double? interestRate,
    LoanStatus? status,
  }) {
    return LoanRequest(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      equipmentName: equipmentName ?? this.equipmentName,
      loanAmount: loanAmount ?? this.loanAmount,
      interestRate: interestRate ?? this.interestRate,
      status: status ?? this.status,
    );
  }
}

class LoanManager extends ChangeNotifier {
  final List<LoanRequest> _requests = [];

  List<LoanRequest> get allRequests => List.unmodifiable(_requests);

  void addLoanRequest(LoanRequest req) {
    _requests.add(req);
    notifyListeners();
  }

  void updateStatus(String id, LoanStatus newStatus) {
    final index = _requests.indexWhere((r) => r.id == id);
    if (index != -1) {
      _requests[index].status = newStatus;
      notifyListeners();
    }
  }

  void deleteRequest(String id) {
    _requests.removeWhere((r) => r.id == id);
    notifyListeners();
  }
}
