// A model for transport service requests
import 'package:cloud_firestore/cloud_firestore.dart';

class TransportRequest {
  final String id;
  final String clientId;
  final String clientName;
  final String providerId;
  final String providerName;
  final String vehicleType;
  final GeoPoint originLocation;
  final String originName;
  final GeoPoint destinationLocation;
  final String destinationName;
  final double distance;
  final double duration;
  final String distanceText;
  final String durationText;
  final double price;
  final String status; // 'pending', 'accepted', 'rejected', 'completed'
  final Timestamp createdAt;
  final Timestamp? acceptedAt;
  final Timestamp? completedAt;  final GeoPoint? clientLocation; // Client's current location
  final String clientAddress; // Client's address
  final Map<String, dynamic>? locationData; // Additional location data for display
  TransportRequest({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.providerId,
    required this.providerName,
    required this.vehicleType,
    required this.originLocation,
    required this.originName,
    required this.destinationLocation,
    required this.destinationName,
    required this.distance,
    required this.duration,
    required this.distanceText,
    required this.durationText,
    required this.price,
    required this.status,
    required this.createdAt,
    this.acceptedAt,
    this.completedAt,
    this.clientLocation,
    this.clientAddress = '',
    this.locationData,
  });
  // Convert model to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'clientName': clientName,
      'providerId': providerId,
      'providerName': providerName,
      'vehicleType': vehicleType,
      'originLocation': originLocation,
      'originName': originName,
      'destinationLocation': destinationLocation,
      'destinationName': destinationName,
      'distance': distance,
      'duration': duration,
      'distanceText': distanceText,
      'durationText': durationText,
      'price': price,
      'status': status,
      'createdAt': createdAt,
      'acceptedAt': acceptedAt,
      'completedAt': completedAt,      'serviceType': 'نقل', // To identify transport requests
      'clientLocation': clientLocation, // Include client location if available
      'clientAddress': clientAddress, // Include client address
      'locationData': locationData, // Include additional location data
    };
  }
  // Create model from Firestore document
  factory TransportRequest.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransportRequest(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      clientName: data['clientName'] ?? '',
      providerId: data['providerId'] ?? '',
      providerName: data['providerName'] ?? '',
      vehicleType: data['vehicleType'] ?? '',
      originLocation: data['originLocation'] ?? GeoPoint(0, 0),
      originName: data['originName'] ?? '',
      destinationLocation: data['destinationLocation'] ?? GeoPoint(0, 0),
      destinationName: data['destinationName'] ?? '',
      distance: (data['distance'] ?? 0).toDouble(),
      duration: (data['duration'] ?? 0).toDouble(),
      distanceText: data['distanceText'] ?? '',
      durationText: data['durationText'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      status: data['status'] ?? 'pending',
      createdAt: data['createdAt'] ?? Timestamp.now(),      acceptedAt: data['acceptedAt'],
      completedAt: data['completedAt'],
      clientLocation: data['clientLocation'], // Extract client location if available
      clientAddress: data['clientAddress'] ?? '', // Extract client address with empty fallback
      locationData: data['locationData'] as Map<String, dynamic>?, // Extract additional location data
    );
  }
}
