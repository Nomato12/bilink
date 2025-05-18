import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:bilink/screens/client_details_screen.dart';
import 'package:bilink/services/notification_service.dart';
import 'package:bilink/services/fcm_service.dart';
import 'package:bilink/screens/request_location_map.dart';
import 'package:bilink/screens/directions_map_tracking.dart';
import 'package:bilink/utils/location_helper.dart';
import 'package:bilink/services/service_vehicles_helper.dart';
import 'package:url_launcher/url_launcher.dart';

class TransportRequestCard extends StatelessWidget {
  final Map<String, dynamic> requestData;
  final VoidCallback? onRequestUpdated;

  const TransportRequestCard({
    super.key,
    required this.requestData,
    this.onRequestUpdated,
  });

  @override
  Widget build(BuildContext context) {
    // Extract data from the request
    final String status = requestData['status'] ?? 'pending';
    final String serviceName = requestData['serviceName'] ?? 'خدمة نقل';
    final String clientName = requestData['clientName'] ?? 'عميل';
    final String details = requestData['details'] ?? '';
    final Timestamp? createdAt = requestData['createdAt'] as Timestamp?;
    
    // Transport-specific data
    final GeoPoint? originLocation = requestData['originLocation'] as GeoPoint?;
    final GeoPoint? destinationLocation = requestData['destinationLocation'] as GeoPoint?;
    final String originName = requestData['originName'] ?? '';
    final String destinationName = requestData['destinationName'] ?? '';    final String distanceText = requestData['distanceText'] ?? '';
    final String durationText = requestData['durationText'] ?? '';
    final String vehicleType = requestData['vehicleType'] ?? '';
    
    // Get price from request data or calculate it if we have distance and vehicle type
    double price = (requestData['price'] ?? 0).toDouble();
    double? distanceValue = requestData['distance'] != null ? (requestData['distance'] as num).toDouble() : null;
    
    // If we have origin and destination location but no price, calculate it
    if (price <= 0 && originLocation != null && destinationLocation != null && vehicleType.isNotEmpty) {
      if (distanceValue != null && distanceValue > 0) {
        // Calculate using the stored distance
        price = ServiceVehiclesHelper.calculatePrice(vehicleType: vehicleType, distanceInKm: distanceValue);
      } else {
        // Calculate using the coordinates
        price = ServiceVehiclesHelper.calculatePriceFromCoordinates(
          vehicleType: vehicleType,
          originLocation: LatLng(originLocation.latitude, originLocation.longitude),
          destinationLocation: LatLng(destinationLocation.latitude, destinationLocation.longitude),
        );
      }
    }

    // Format date
    final String formattedCreatedAt = createdAt != null
        ? DateFormat('yyyy/MM/dd hh:mm a').format(createdAt.toDate())
        : 'غير معروف';

    // Define colors based on status
    Color statusColor;
    String statusText;

    switch (status) {
      case 'accepted':
        statusColor = Colors.green;
        statusText = 'تم القبول';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'تم الرفض';
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'قيد الانتظار';
    }

    // Create map markers if location data is available
    final Set<Marker> markers = {};
    if (originLocation != null && destinationLocation != null) {
      // Origin marker
      markers.add(
        Marker(
          markerId: const MarkerId('origin'),
          position: LatLng(originLocation.latitude, originLocation.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: 'نقطة الانطلاق', snippet: originName),
        ),
      );

      // Destination marker
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(destinationLocation.latitude, destinationLocation.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'نقطة الوصول', snippet: destinationName),
        ),
      );
    }

    // Calculate visible region for static map
    LatLngBounds? mapBounds;
    if (originLocation != null && destinationLocation != null) {
      mapBounds = LatLngBounds(
        southwest: LatLng(
          math.min(originLocation.latitude, destinationLocation.latitude),
          math.min(originLocation.longitude, destinationLocation.longitude),
        ),
        northeast: LatLng(
          math.max(originLocation.latitude, destinationLocation.latitude),
          math.max(originLocation.longitude, destinationLocation.longitude),
        ),
      );
    }    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: statusColor.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showRequestDetails(context),
          child: Padding(
            padding: const EdgeInsets.all(16),            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Enhanced header with service name and status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.local_shipping_rounded,
                              color: Color(0xFF8B5CF6),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              serviceName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF1F2937),
                                letterSpacing: 0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Enhanced price section with calculation details                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.attach_money_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'سعر الخدمة:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                ServiceVehiclesHelper.formatPrice(price).split(' ')[0], // Get just the number part
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(                                'دج',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),// Price details section removed
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Client name and time
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      size: 16,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'العميل: $clientName',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.access_time,
                      size: 16,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formattedCreatedAt,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Transport route info
                if (originName.isNotEmpty || destinationName.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Origin
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.trip_origin,
                                size: 14,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                originName.isNotEmpty ? originName : 'نقطة الانطلاق',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (originName.isNotEmpty && destinationName.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: CustomPaint(
                              size: const Size(2, 24),
                              painter: _DashedLinePainter(),
                            ),
                          ),
                        // Destination
                        if (destinationName.isNotEmpty)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  destinationName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        // Distance and duration info
                        if (distanceText.isNotEmpty || durationText.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (distanceText.isNotEmpty) ...[
                                  const Icon(
                                    Icons.straighten,
                                    size: 14,
                                    color: Color(0xFF6B7280),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    distanceText,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                  if (durationText.isNotEmpty)
                                    const SizedBox(width: 8),
                                ],
                                if (durationText.isNotEmpty) ...[
                                  const Icon(
                                    Icons.timer_outlined,
                                    size: 14,
                                    color: Color(0xFF6B7280),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    durationText,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),                // Action buttons
                Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Client details button
                    _buildActionButton(
                      context,
                      icon: Icons.person,
                      label: 'بيانات العميل',
                      onPressed: () => _viewClientDetails(context),
                    ),
                    
                    // Map button
                    if (originLocation != null && destinationLocation != null)
                      _buildActionButton(
                        context,
                        icon: Icons.map,
                        label: 'عرض الخريطة',
                        onPressed: () => _viewOnMap(context),
                      ),
                    
                    // New navigation button with turn-by-turn directions
                    if (originLocation != null && destinationLocation != null)
                      _buildActionButton(
                        context,
                        icon: Icons.navigation,
                        label: 'ملاحة بالإرشادات',
                        onPressed: () => _navigateWithDirections(context),
                      ),
                    
                    // Call client button
                    _buildActionButton(
                      context,
                      icon: Icons.phone,
                      label: 'اتصال',
                      onPressed: () => _callClient(),
                    ),
                  ],
                ),
                
                // Request status actions (only for pending requests)
                if (status == 'pending')
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _acceptRequest(context),
                            icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                            label: const Text('قبول', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _rejectRequest(context),
                            icon: const Icon(Icons.cancel_outlined, color: Colors.white),
                            label: const Text('رفض', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build action buttons
  Widget _buildActionButton(BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF8B5CF6)),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF4B5563),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // View client details
  void _viewClientDetails(BuildContext context) {
    final String clientId = requestData['clientId'] ?? '';
    if (clientId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ClientDetailsScreen(clientId: clientId),
        ),
      );
    } else {
      _showErrorSnackBar(context, 'لا توجد معلومات متاحة عن العميل');
    }
  }
  // View locations on map
  void _viewOnMap(BuildContext context) {
    final GeoPoint? originLocation = requestData['originLocation'] as GeoPoint?;
    final GeoPoint? destinationLocation = requestData['destinationLocation'] as GeoPoint?;
    
    if (originLocation != null && destinationLocation != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RequestLocationMap(
            location: originLocation,
            title: requestData['originName'] ?? 'نقطة الانطلاق',
            destinationLocation: destinationLocation,
            destinationName: requestData['destinationName'] ?? 'الوجهة',
            address: requestData['originAddress'] ?? '',
            enableNavigation: true,
            showRouteToCurrent: true,
            requestId: requestData['id'],
          ),
        ),
      );
    } else {
      _showErrorSnackBar(context, 'معلومات الموقع غير متوفرة');
    }
  }

  // Navigate with turn-by-turn directions
  void _navigateWithDirections(BuildContext context) {
    final GeoPoint? originLocation = requestData['originLocation'] as GeoPoint?;
    final GeoPoint? destinationLocation = requestData['destinationLocation'] as GeoPoint?;
    
    if (originLocation != null && destinationLocation != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LiveTrackingMapScreen(
            originLocation: LatLng(originLocation.latitude, originLocation.longitude),
            originName: requestData['originName'] ?? 'نقطة الانطلاق',
            destinationLocation: LatLng(destinationLocation.latitude, destinationLocation.longitude),
            destinationName: requestData['destinationName'] ?? 'الوجهة',
          ),
        ),
      );
    } else {
      _showErrorSnackBar(context, 'معلومات الموقع غير متوفرة للملاحة');
    }
  }

  // Call client
  void _callClient() async {
    final String clientPhone = requestData['clientPhone'] ?? '';
    if (clientPhone.isNotEmpty) {
      final Uri phoneUri = Uri(
        scheme: 'tel',
        path: clientPhone,
      );
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      }
    }
  }  // Show request details
  void _showRequestDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Extract necessary data within the builder scope
        final String detailVehicleType = requestData['vehicleType'] ?? '';
        final double detailPrice = (requestData['price'] ?? 0).toDouble();
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'تفاصيل الطلب',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 24),
                
                // Price section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'سعر الخدمة',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [                          Text(
                            ServiceVehiclesHelper.formatPrice(detailPrice).split(' ')[0], // Get just the number part
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 28,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'دج',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),                      // Price calculation details
                      if (detailVehicleType.isNotEmpty) 
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Text(
                                      'نوع المركبة: $detailVehicleType',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Text(
                                      'المسافة: ${requestData['distanceText'] ?? ''}',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Service and client details
                _buildDetailItem('اسم الخدمة:', requestData['serviceName'] ?? ''),
                _buildDetailItem('نوع الخدمة:', 'نقل'),
                _buildDetailItem('اسم العميل:', requestData['clientName'] ?? ''),
                _buildDetailItem('هاتف العميل:', requestData['clientPhone'] ?? ''),
                
                // Trip details section
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'تفاصيل الرحلة',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                
                // Origin and destination details
                _buildLocationItem(
                  'نقطة الانطلاق:',
                  requestData['originName'] ?? '',
                  Icons.trip_origin,
                  Colors.green,
                ),
                _buildLocationItem(
                  'نقطة الوصول:',
                  requestData['destinationName'] ?? '',
                  Icons.location_on,
                  Colors.red,
                ),
                _buildDetailItem('المسافة:', requestData['distanceText'] ?? ''),
                _buildDetailItem('الوقت التقريبي:', requestData['durationText'] ?? ''),
                _buildDetailItem('نوع المركبة:', requestData['vehicleType'] ?? ''),

                // Request description
                if (requestData['details']?.isNotEmpty ?? false) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 16, bottom: 8),
                    child: Text(
                      'وصف الطلب',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      requestData['details'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 24),
                
                // Action buttons
                if (requestData['status'] == 'pending')
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _acceptRequest(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('قبول الطلب', style: TextStyle(fontSize: 16, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _rejectRequest(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('رفض الطلب', style: TextStyle(fontSize: 16, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Build detail item helper
  Widget _buildDetailItem(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4B5563),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build location item helper
  Widget _buildLocationItem(String label, String value, IconData icon, Color color) {
    if (value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 14,
              color: color,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // Accept request
  Future<void> _acceptRequest(BuildContext context) async {
    try {
      final notificationService = NotificationService();
      final fcmService = FcmService();
      final String requestId = requestData['id'];
      final String clientId = requestData['clientId'] ?? '';
      final String providerId = FirebaseAuth.instance.currentUser?.uid ?? '';
      
      if (requestId.isEmpty || clientId.isEmpty || providerId.isEmpty) {
        _showErrorSnackBar(context, 'بيانات الطلب غير مكتملة');
        return;
      }
      
      // Update request status in Firestore
      await notificationService.updateRequestStatus(
        requestId: requestId,
        status: 'accepted',
      );
      
      // Send push notification to client
      await fcmService.sendNotificationToUser(
        userId: clientId,
        title: 'تم قبول طلبك',
        body: 'تم قبول طلب النقل الخاص بك من قبل مزود الخدمة',
        data: {
          'type': 'request_accepted',
          'requestId': requestId,
          'providerId': providerId,
        },
      );
      
      // Update UI
      if (onRequestUpdated != null) {
        onRequestUpdated!();
      }
      
      _showSuccessSnackBar(context, 'تم قبول الطلب بنجاح');
    } catch (e) {
      _showErrorSnackBar(context, 'حدث خطأ أثناء قبول الطلب');
    }
  }
  // Reject request
  Future<void> _rejectRequest(BuildContext context) async {
    try {
      final notificationService = NotificationService();
      final fcmService = FcmService();
      final String requestId = requestData['id'];
      final String clientId = requestData['clientId'] ?? '';
      final String providerId = FirebaseAuth.instance.currentUser?.uid ?? '';
      
      if (requestId.isEmpty || clientId.isEmpty || providerId.isEmpty) {
        _showErrorSnackBar(context, 'بيانات الطلب غير مكتملة');
        return;
      }
      
      // Update request status in Firestore
      await notificationService.updateRequestStatus(
        requestId: requestId,
        status: 'rejected',
      );
      
      // Send push notification to client
      await fcmService.sendNotificationToUser(
        userId: clientId,
        title: 'تم رفض طلبك',
        body: 'تم رفض طلب النقل الخاص بك من قبل مزود الخدمة',
        data: {
          'type': 'request_rejected',
          'requestId': requestId,
          'providerId': providerId,
        },
      );
      
      // Update UI
      if (onRequestUpdated != null) {
        onRequestUpdated!();
      }
      
      _showSuccessSnackBar(context, 'تم رفض الطلب');
    } catch (e) {
      _showErrorSnackBar(context, 'حدث خطأ أثناء رفض الطلب');
    }
  }

  // Show error snackbar
  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Show success snackbar
  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// Custom painter for dashed line
class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9CA3AF)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    
    const dashWidth = 3.0;
    const dashSpace = 3.0;
    double startY = 0;
    
    while (startY < size.height) {
      canvas.drawLine(
        Offset(0, startY),
        Offset(0, startY + dashWidth),
        paint,
      );
      startY += dashWidth + dashSpace;
    }
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
