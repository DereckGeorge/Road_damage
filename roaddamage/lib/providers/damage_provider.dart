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
  final String? surveyStatus;
  final String? stage;
  final int? roadBudget;
  final DateTime? surveyStartDate;
  final DateTime? surveyEndDate;
  final DateTime? repairDate;

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
    this.surveyStatus,
    this.stage,
    this.roadBudget,
    this.surveyStartDate,
    this.surveyEndDate,
    this.repairDate,
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
      surveyStatus: json['surveyStatus'],
      stage: json['stage'],
      roadBudget: json['roadBudget'],
      surveyStartDate: json['surveyStartDate'] != null
          ? DateTime.parse(json['surveyStartDate'])
          : null,
      surveyEndDate: json['surveyEndDate'] != null
          ? DateTime.parse(json['surveyEndDate'])
          : null,
      repairDate: json['repairDate'] != null
          ? DateTime.parse(json['repairDate'])
          : null,
    );
  }
}

class AssignedRoad {
  final String id;
  final String roadName;
  final String assignedSurveyor;
  final String status;

  AssignedRoad({
    required this.id,
    required this.roadName,
    required this.assignedSurveyor,
    required this.status,
  });

  factory AssignedRoad.fromJson(Map<String, dynamic> json) {
    return AssignedRoad(
      id: json['_id'],
      roadName: json['roadName'],
      assignedSurveyor: json['assignedSurveyor'],
      status: json['status'],
    );
  }
}

class DamageProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<DamageClass> _damageClasses = [];
  List<DamageReport> _reports = [];
  List<DamageReport> _rejectedPhotos = [];
  List<AssignedRoad> _assignedRoads = [];
  bool _isLoading = false;

  List<DamageClass> get damageClasses => _damageClasses;
  List<DamageReport> get reports => _reports;
  List<DamageReport> get rejectedPhotos => _rejectedPhotos;
  List<AssignedRoad> get assignedRoads => _assignedRoads;
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

  Future<void> loadAssignedRoads(String email) async {
    try {
      _isLoading = true;
      notifyListeners();

      final data = await _apiService.getAssignedRoads(email);
      _assignedRoads = data.map((json) => AssignedRoad.fromJson(json)).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadRejectedPhotos(String email) async {
    try {
      _isLoading = true;
      notifyListeners();

      final data = await _apiService.getRejectedPhotos(email);
      _rejectedPhotos = (data['photos'] as List)
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

  Future<void> uploadPhoto({
    required String userId,
    required String fullname,
    required String email,
    required String imageData,
    required Map<String, dynamic> location,
    required String roadName,
    required String damageClass,
    required String comment,
    required String surveyStartDate,
    required String surveyEndDate,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _apiService.uploadPhoto(
        userId: userId,
        fullname: fullname,
        email: email,
        imageData: imageData,
        location: location,
        roadName: roadName,
        damageClass: damageClass,
        comment: comment,
        surveyStartDate: surveyStartDate,
        surveyEndDate: surveyEndDate,
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

  Future<void> editRejectedPhoto({
    required String photoId,
    required String roadName,
    required String damageClass,
    required String comment,
    required String editReason,
    required String email,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _apiService.editPhoto(
        photoId: photoId,
        roadName: roadName,
        damageClass: damageClass,
        comment: comment,
        editReason: editReason,
      );
      await loadRejectedPhotos(email);
      await loadReports();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<DamageReport> getFilteredReports({
    DateTime? startDate,
    DateTime? endDate,
    String? damageClass,
    String? roadName,
    String? status,
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
      bool matchesRoad = roadName == null ||
          report.roadName.toLowerCase().contains(roadName.toLowerCase());
      bool matchesStatus = status == null || report.approvalStatus == status;
      return matchesDate && matchesClass && matchesRoad && matchesStatus;
    }).toList();
  }
}
