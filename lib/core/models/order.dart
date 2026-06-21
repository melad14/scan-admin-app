import 'service.dart';
import 'technician.dart';

class OrderStatusLog {
  final String status;
  final DateTime timestamp;
  final String? note;

  OrderStatusLog({
    required this.status,
    required this.timestamp,
    this.note,
  });

  factory OrderStatusLog.fromJson(Map<String, dynamic> json) {
    return OrderStatusLog(
      status: json['status'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      note: json['note'],
    );
  }
}

class OrderReport {
  final List<String> images;
  final String? pdf;
  final DateTime? uploadedAt;
  final String? notes;

  OrderReport({
    required this.images,
    this.pdf,
    this.uploadedAt,
    this.notes,
  });

  factory OrderReport.fromJson(Map<String, dynamic> json) {
    return OrderReport(
      images: List<String>.from(json['images'] ?? []),
      pdf: json['pdf'],
      uploadedAt: json['uploadedAt'] != null ? DateTime.parse(json['uploadedAt']) : null,
      notes: json['notes'],
    );
  }
}

class MedicalOrder {
  final String id;
  final String orderNumber;
  final String serviceCategory;
  final List<MedicalService> services;
  final Map<String, dynamic>? patientSnapshot;
  final Map<String, dynamic>? caseDetails;
  final Map<String, dynamic>? location;
  final Map<String, dynamic>? schedule;
  final Map<String, dynamic>? pricing;
  final Map<String, dynamic>? payment;
  final String status;
  final List<OrderStatusLog> statusHistory;
  final MedicalTechnician? technician;
  final OrderReport? report;
  final double? technicianRating;
  final String? technicianReview;
  final DateTime createdAt;

  MedicalOrder({
    required this.id,
    required this.orderNumber,
    required this.serviceCategory,
    required this.services,
    this.patientSnapshot,
    this.caseDetails,
    this.location,
    this.schedule,
    this.pricing,
    this.payment,
    required this.status,
    required this.statusHistory,
    this.technician,
    this.report,
    this.technicianRating,
    this.technicianReview,
    required this.createdAt,
  });

  factory MedicalOrder.fromJson(Map<String, dynamic> json) {
    return MedicalOrder(
      id: json['_id'] ?? json['id'] ?? '',
      orderNumber: json['orderNumber'] ?? '',
      serviceCategory: json['serviceCategory'] ?? '',
      services: (json['services'] as List? ?? [])
          .map((item) => MedicalService.fromJson(item))
          .toList(),
      patientSnapshot: json['patientSnapshot'],
      caseDetails: json['caseDetails'],
      location: json['location'],
      schedule: json['schedule'],
      pricing: json['pricing'],
      payment: json['payment'],
      status: json['status'] ?? 'pending',
      statusHistory: (json['statusHistory'] as List? ?? [])
          .map((item) => OrderStatusLog.fromJson(item))
          .toList(),
      technician: (json['technician'] != null && json['technician'] is Map<String, dynamic>)
          ? MedicalTechnician.fromJson(json['technician'] as Map<String, dynamic>)
          : null,
      report: json['report'] != null ? OrderReport.fromJson(json['report']) : null,
      technicianRating: (json['technicianRating'] as num?)?.toDouble(),
      technicianReview: json['technicianReview'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}
