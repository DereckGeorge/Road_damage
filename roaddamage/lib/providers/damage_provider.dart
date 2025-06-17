import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class DamageClass {
  final String id;
  final String damageClass;
  final String description;
  final int repairCost;

  DamageClass({
    required this.id,
    required this.damageClass,
    required this.description,
    required this.repairCost,
  });

  factory DamageClass.fromJson(Map<String, dynamic> json) {
    return DamageClass(
      id: json['_id'],
      damageClass: json['damageClass'],
      description: json['description'],
      repairCost: json['repairCost'],
    );
  }
}

class DamageReport {
  final String id;
  final String userId;
  final String fullname;
  final String email;
  final String roadName;
  final String damageClass;
  final String comment;
  final String photoUrl;
  final Map<String, dynamic> location;
  final String approvalStatus;
  final DateTime dateCreated;
  final String? contractor;
  final String? officerComment;
  final String? validatedByOfficerId;
  final DateTime? validationDate;

  DamageReport({
    required this.id,
    required this.userId,
    required this.fullname,
    required this.email,
    required this.roadName,
    required this.damageClass,
    required this.comment,
    required this.photoUrl,
    required this.location,
    required this.approvalStatus,
    required this.dateCreated,
    this.contractor,
    this.officerComment,
    this.validatedByOfficerId,
    this.validationDate,
  });

  factory DamageReport.fromJson(Map<String, dynamic> json) {
    return DamageReport(
      id: json['_id'],
      userId: json['userId'],
      fullname: json['fullname'],
      email: json['email'],
      roadName: json['roadName'],
      damageClass: json['damageClass'],
      comment: json['comment'],
      photoUrl: json['photoUrl'],
      location: json['location'],
      approvalStatus: json['approvalStatus'],
      dateCreated: DateTime.parse(json['dateCreated']),
      contractor: json['contractor'],
      officerComment: json['officerComment'],
      validatedByOfficerId: json['validatedByOfficerId'],
      validationDate: json['validationDate'] != null
          ? DateTime.parse(json['validationDate'])
          : null,
    );
  }
}

class DamageProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<DamageClass> _damageClasses = [];
  List<DamageReport> _reports = [];
  bool _isLoading = false;

  List<DamageClass> get damageClasses => _damageClasses;
  List<DamageReport> get reports => _reports;
  bool get isLoading => _isLoading;

  Future<void> loadDamageClasses() async {
    try {
      _isLoading = true;
      notifyListeners();

      final data = await _apiService.getDamageClasses();
      _damageClasses = data.map((json) => DamageClass.fromJson(json)).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadReports() async {
    try {
      _isLoading = true;
      notifyListeners();

      final data = await _apiService.getReports();
      _reports = (data['photos'] as List)
          .map((json) => DamageReport.fromJson(json))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> submitReport({
    required String userId,
    required String fullname,
    required String email,
    required String imageData,
    required Map<String, dynamic> location,
    required String roadName,
    required String damageClass,
    required String comment,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _apiService.submitReport(
        userId: userId,
        fullname: fullname,
        email: email,
        imageData: imageData,
        location: location,
        roadName: roadName,
        damageClass: damageClass,
        comment: comment,
      );

      // Reload reports after submission
      await loadReports();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  List<DamageReport> getFilteredReports({
    DateTime? startDate,
    DateTime? endDate,
    String? damageClass,
  }) {
    return _reports.where((report) {
      bool matchesDate = true;
      if (startDate != null) {
        matchesDate = matchesDate && report.dateCreated.isAfter(startDate);
      }
      if (endDate != null) {
        matchesDate = matchesDate && report.dateCreated.isBefore(endDate);
      }
      bool matchesClass =
          damageClass == null || report.damageClass == damageClass;
      return matchesDate && matchesClass;
    }).toList();
  }
}
