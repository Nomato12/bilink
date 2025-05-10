import 'package:cloud_firestore/cloud_firestore.dart';

enum ServiceRequestStatus {
  pending, // في انتظار الرد
  accepted, // تمت الموافقة
  rejected, // تم الرفض
  completed, // تم الإكمال
  cancelled // تم الإلغاء
}

class ServiceRequest {
  final String id;
  final String serviceId;
  final String serviceTitle;
  final String providerId;
  final String clientId;
  final String clientName;
  final String providerName;
  final DateTime requestDate;
  final DateTime? responseDate;
  final DateTime scheduledDate;
  final String details;
  final ServiceRequestStatus status;
  final bool isRead;

  ServiceRequest({
    required this.id,
    required this.serviceId,
    required this.serviceTitle,
    required this.providerId,
    required this.clientId,
    required this.clientName, 
    required this.providerName,
    required this.requestDate,
    this.responseDate,
    required this.scheduledDate,
    required this.details,
    required this.status,
    this.isRead = false,
  });

  factory ServiceRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ServiceRequest(
      id: doc.id,
      serviceId: data['serviceId'] ?? '',
      serviceTitle: data['serviceTitle'] ?? '',
      providerId: data['providerId'] ?? '',
      clientId: data['clientId'] ?? '',
      clientName: data['clientName'] ?? '',
      providerName: data['providerName'] ?? '',
      requestDate: (data['requestDate'] as Timestamp).toDate(),
      responseDate: data['responseDate'] != null 
          ? (data['responseDate'] as Timestamp).toDate() 
          : null,
      scheduledDate: (data['scheduledDate'] as Timestamp).toDate(),
      details: data['details'] ?? '',
      status: ServiceRequestStatus.values.byName(data['status'] ?? 'pending'),
      isRead: data['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'serviceId': serviceId,
      'serviceTitle': serviceTitle,
      'providerId': providerId,
      'clientId': clientId,
      'clientName': clientName,
      'providerName': providerName,
      'requestDate': FieldValue.serverTimestamp(),
      'responseDate': responseDate != null ? Timestamp.fromDate(responseDate!) : null,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'details': details,
      'status': status.name,
      'isRead': isRead,
    };
  }

  ServiceRequest copyWith({
    String? id,
    String? serviceId,
    String? serviceTitle,
    String? providerId,
    String? clientId,
    String? clientName,
    String? providerName,
    DateTime? requestDate,
    DateTime? responseDate,
    DateTime? scheduledDate,
    String? details,
    ServiceRequestStatus? status,
    bool? isRead,
  }) {
    return ServiceRequest(
      id: id ?? this.id,
      serviceId: serviceId ?? this.serviceId,
      serviceTitle: serviceTitle ?? this.serviceTitle,
      providerId: providerId ?? this.providerId,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      providerName: providerName ?? this.providerName,
      requestDate: requestDate ?? this.requestDate,
      responseDate: responseDate ?? this.responseDate,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      details: details ?? this.details,
      status: status ?? this.status,
      isRead: isRead ?? this.isRead,
    );
  }
}
