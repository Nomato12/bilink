import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { client, provider, admin }

class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String phoneNumber;
  final UserRole role;
  final String? companyName;
  final bool isPhoneVerified;
  final Map<String, dynamic> additionalData;
  final DateTime createdAt;
  final DateTime lastLogin;
  final String profileImageUrl;

  UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
    this.companyName,
    this.isPhoneVerified = false,
    this.additionalData = const {},
    DateTime? createdAt,
    DateTime? lastLogin,
    this.profileImageUrl = '',
  }) : createdAt = createdAt ?? DateTime.now(),
       lastLogin = lastLogin ?? DateTime.now();

  // Factory constructor para crear un usuario desde un documento de Firestore
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      role: _parseRole(data['role']),
      companyName: data['companyName'],
      isPhoneVerified: data['isPhoneVerified'] ?? false,
      additionalData: data['additionalData'] ?? {},
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLogin: (data['lastLogin'] as Timestamp?)?.toDate() ?? DateTime.now(),
      profileImageUrl: data['profileImageUrl'] ?? '',
    );
  }

  // Helper para convertir string en enumeración
  static UserRole _parseRole(String? roleStr) {
    if (roleStr == 'provider') {
      return UserRole.provider;
    } else if (roleStr == 'admin') {
      return UserRole.admin;
    } else {
      return UserRole.client;
    }
  }

  // الحصول على الدور كنص
  String get roleAsString {
    switch (role) {
      case UserRole.client:
        return 'client';
      case UserRole.provider:
        return 'provider';
      case UserRole.admin:
        return 'admin';
      default:
        return 'client';
    }
  }

  // Convertir a un Map para guardar en Firestore
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'role': roleAsString,
      'companyName': companyName,
      'isPhoneVerified': isPhoneVerified,
      'additionalData': additionalData,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLogin': Timestamp.fromDate(lastLogin),
      'profileImageUrl': profileImageUrl,
    };
  }

  // Crear modelo desde un Map
  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      role: _parseRole(data['role']),
      companyName: data['companyName'],
      isPhoneVerified: data['isPhoneVerified'] ?? false,
      additionalData: data['additionalData'] ?? {},
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLogin: (data['lastLogin'] as Timestamp?)?.toDate() ?? DateTime.now(),
      profileImageUrl: data['profileImageUrl'] ?? '',
    );
  }

  // Copiar el modelo مع تحديث بعض الخصائص
  UserModel copyWith({
    String? uid,
    String? email,
    String? fullName,
    String? phoneNumber,
    UserRole? role,
    String? companyName,
    bool? isPhoneVerified,
    Map<String, dynamic>? additionalData,
    DateTime? createdAt,
    DateTime? lastLogin,
    String? profileImageUrl,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      companyName: companyName ?? this.companyName,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      additionalData: additionalData ?? this.additionalData,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }
}
