import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:bilink/screens/client_details_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:bilink/services/fcm_service.dart';
import 'package:bilink/services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bilink/screens/full_screen_map.dart';
import 'package:bilink/screens/client_location_map.dart';
import 'package:bilink/utils/location_helper.dart';

// Import request_location_map.dart
import 'package:bilink/screens/request_location_map.dart';

class ServiceRequestCard extends StatelessWidget {
  final Map<String, dynamic> requestData;
  final VoidCallback? onRequestUpdated;

  const ServiceRequestCard({
    super.key,
    required this.requestData,
    this.onRequestUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Extract data from the request
    final String status = requestData['status'] ?? 'pending';
    final String serviceName = requestData['serviceName'] ?? 'خدمة';
    final String clientName = requestData['clientName'] ?? 'عميل';
    final String details = requestData['details'] ?? '';
    final String serviceType = requestData['serviceType'] ?? 'تخزين';
    final Timestamp? createdAt = requestData['createdAt'] as Timestamp?;
    // Transport-specific data
    final GeoPoint? originLocation = requestData['originLocation'] as GeoPoint?;
    final GeoPoint? destinationLocation = requestData['destinationLocation'] as GeoPoint?;
    final String originName = requestData['originName'] ?? '';
    final String destinationName = requestData['destinationName'] ?? '';
    final String distanceText = requestData['distanceText'] ?? '';
    final String durationText = requestData['durationText'] ?? '';
    final String vehicleType = requestData['vehicleType'] ?? '';
    final double price = (requestData['price'] ?? 0).toDouble();
    // Get client location using helper
    GeoPoint? clientLocation = LocationHelper.getLocationFromData(requestData);
    String clientAddress = LocationHelper.getAddressFromData(requestData);
    bool isLiveLocation = LocationHelper.isLocationRecent(requestData);

    // If client location is null, try to use origin or destination for transport requests
    if (clientLocation == null && serviceType == 'نقل') {
      if (originLocation != null) {
        clientLocation = originLocation;
        // Set the display address to origin location for better UX
        clientAddress = originName.isNotEmpty ? originName : 'نقطة الانطلاق';
        isLiveLocation = false;
      } else if (destinationLocation != null) {
        clientLocation = destinationLocation;
        // Set the display address to destination location for better UX
        clientAddress = destinationName.isNotEmpty ? destinationName : 'نقطة الوصول';
        isLiveLocation = false;
      }
    }

    // Format date
    final String formattedCreatedAt = createdAt != null
        ? DateFormat('yyyy/MM/dd hh:mm a').format(createdAt.toDate())
        : 'غير معروف';

    // Define colors based on status
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'accepted':
        statusColor = Colors.green.shade600;
        statusText = 'تم القبول';
        statusIcon = Icons.check_circle_outline_rounded;
        break;      case 'rejected':
        statusColor = Colors.red.shade600;
        statusText = 'تم الرفض';
        statusIcon = Icons.cancel_outlined;
        break;
      case 'completed':
        statusColor = Colors.blue.shade600;
        statusText = 'مكتمل';
        statusIcon = Icons.task_alt_rounded;
        break;
      default:
        statusColor = Colors.orange.shade600;
        statusText = 'قيد الانتظار';
        statusIcon = Icons.hourglass_empty_rounded;
    }

    // Create map markers if location data is available
    final Set<Marker> markers = {};
    if (serviceType == 'نقل' && originLocation != null && destinationLocation != null) {
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
          infoWindow: InfoWindow(title: 'الوجهة', snippet: destinationName),
        ),
      );
    }

    // Calculate map camera position
    CameraPosition? initialCameraPosition;
    if (serviceType == 'نقل' && originLocation != null && destinationLocation != null) {
      // Center the map between origin and destination
      final double avgLat = (originLocation.latitude + destinationLocation.latitude) / 2;
      final double avgLng = (originLocation.longitude + destinationLocation.longitude) / 2;

      // Calculate zoom level based on distance
      final double latDiff = (originLocation.latitude - destinationLocation.latitude).abs();
      final double lngDiff = (originLocation.longitude - destinationLocation.longitude).abs();
      final double maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
      final double zoom = maxDiff > 0.1 ? 10.0 : (maxDiff > 0.05 ? 12.0 : 14.0);

      initialCameraPosition = CameraPosition(
        target: LatLng(avgLat, avgLng),
        zoom: zoom,
      );
    }
    IconData serviceTypeIcon = serviceType == 'نقل' ? Icons.local_shipping_rounded : Icons.inventory_2_rounded;
    Color serviceTypeColor = serviceType == 'نقل' ? Colors.blue.shade700 : Colors.teal.shade700;
     
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service name and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: serviceTypeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(serviceTypeIcon, color: serviceTypeColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              serviceName,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // Badge: service type
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: serviceTypeColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: serviceTypeColor.withOpacity(0.3), width: 1),
                              ),
                              child: Text(
                                serviceType == 'نقل' ? 'خدمة نقل' : 'خدمة تخزين',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: serviceTypeColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Status chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.4), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.grey.shade300, height: 1),
            const SizedBox(height: 16),

            // Client name and creation date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 18, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ClientDetailsScreen(
                                clientId: requestData['clientId'] ?? '',
                              ),
                            ),
                          );
                        },
                        child: Text(
                          clientName,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 16, color: Colors.grey.shade700),
                    const SizedBox(width: 8),
                    Text(
                      formattedCreatedAt,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Show transport-specific details for transport service
            if (serviceType == 'نقل' && originLocation != null && destinationLocation != null) ...[
              const SizedBox(height: 16),
              // Map view
              GestureDetector(
                onTap: () => _showFullMap(context),
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        GoogleMap(
                          initialCameraPosition: initialCameraPosition!,
                          markers: markers,
                          zoomControlsEnabled: false,
                          mapToolbarEnabled: false,
                          myLocationButtonEnabled: false,
                          compassEnabled: false,
                          rotateGesturesEnabled: false,
                          scrollGesturesEnabled: false,
                          zoomGesturesEnabled: false,
                          tiltGesturesEnabled: false,
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.black.withOpacity(0.0), Colors.black.withOpacity(0.7)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildMapOverlayButton(
                                  context,
                                  icon: Icons.near_me_rounded,
                                  label: 'للانطلاق',
                                  onPressed: () => _openLocationInMaps(context, originLocation, 'نقطة الانطلاق: $originName'),
                                ),
                                _buildMapOverlayButton(
                                  context,
                                  icon: Icons.pin_drop_rounded,
                                  label: 'للوجهة',
                                  onPressed: () => _openLocationInMaps(context, destinationLocation, 'الوجهة: $destinationName'),
                                ),
                                _buildMapOverlayButton(
                                  context,
                                  icon: Icons.directions_rounded,
                                  label: 'مسار كامل',
                                  onPressed: () => _openDirectionsInMaps(context, originLocation, destinationLocation, originName, destinationName),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Tooltip(
                            message: 'فتح الخريطة بشكل كامل',
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: theme.cardColor.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]
                              ),
                              child: Icon(
                                Icons.fullscreen_rounded,
                                color: theme.colorScheme.primary,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Transport details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(context, Icons.trip_origin_rounded, 'من:', originName, color: Colors.green.shade700),
                    const SizedBox(height: 10),
                    _buildDetailRow(context, Icons.location_on_rounded, 'إلى:', destinationName, color: Colors.red.shade700),
                    const SizedBox(height: 12),
                    Divider(color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoChip(context, Icons.route_rounded, distanceText, Colors.blue.shade700),
                        _buildInfoChip(context, Icons.access_time_rounded, durationText, Colors.orange.shade700),
                        _buildInfoChip(context, Icons.local_shipping_rounded, vehicleType, Colors.purple.shade700),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Price
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'السعر: ',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '$price',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'دج',
                           style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // Show client location section for accepted requests
            if (status == 'accepted') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.green.shade700, size: 24),
                        const SizedBox(width: 10),
                        Text(
                          'معلومات العميل',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (clientLocation != null) ...[
                      if (clientAddress.isNotEmpty)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_city_rounded, color: Colors.grey.shade600, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                clientAddress,
                                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade800),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isLiveLocation) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade600,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.gps_fixed_rounded, color: Colors.white, size: 12),
                                    SizedBox(width: 4),
                                    Text(
                                      'مباشر',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _showClientLocationOnMap(context, clientLocation, clientName, data: requestData),
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              children: [
                                GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: LatLng(clientLocation.latitude, clientLocation.longitude),
                                    zoom: 14.5,
                                  ),
                                  markers: {
                                    Marker(
                                      markerId: const MarkerId('clientLocation'),
                                      position: LatLng(clientLocation.latitude, clientLocation.longitude),
                                      infoWindow: InfoWindow(title: 'موقع $clientName'),
                                    ),
                                  },
                                  zoomControlsEnabled: false,
                                  mapToolbarEnabled: false,
                                  myLocationButtonEnabled: false,
                                  compassEnabled: false,
                                  rotateGesturesEnabled: false,
                                  scrollGesturesEnabled: false,
                                  zoomGesturesEnabled: false,
                                  tiltGesturesEnabled: false,
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    color: Colors.black.withOpacity(0.6),
                                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                    child: const Text(
                                      'انقر لفتح الخريطة والتتبع',
                                      style: TextStyle(color: Colors.white, fontSize: 11),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showClientLocationOnMap(context, clientLocation, clientName, data: requestData),
                              icon: const Icon(Icons.map_outlined, size: 18),
                              label: const Text('الخريطة'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue.shade700,
                                side: BorderSide(color: Colors.blue.shade700),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showClientLocationOnMap(context, clientLocation, clientName, showRoute: true, data: requestData),
                              icon: const Icon(Icons.route_outlined, size: 18),
                              label: const Text('المسار'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.purple.shade700,
                                side: BorderSide(color: Colors.purple.shade700),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildRouteButton(context, clientLocation, clientName),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ClientDetailsScreen(
                                  clientId: requestData['clientId'] ?? '',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.info_outline_rounded, size: 18),
                          label: const Text('عرض معلومات العميل'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.blue.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Regular request details for other service types
            if (serviceType != 'نقل' || originLocation == null || destinationLocation == null) ...[
              const SizedBox(height: 12),
              // Request details
              if (details.isNotEmpty) ...[
                Text(
                  'التفاصيل:',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    details,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.9),
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],

            const SizedBox(height: 20),

            // Action buttons based on status
            if (status == 'pending') ...[
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      context: context,
                      label: 'قبول',
                      icon: Icons.check_circle_outline_rounded,
                      backgroundColor: Colors.green.shade600,
                      textColor: Colors.white,
                      onPressed: () => _updateRequestStatus(context, 'accepted'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(                    child: _buildActionButton(
                      context: context,
                      label: 'رفض',
                      icon: Icons.cancel_outlined,
                      backgroundColor: Colors.red.shade600,
                      textColor: Colors.white,
                      onPressed: () => _updateRequestStatus(context, 'rejected'),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'accepted') ...[
              Column(
                children: [
                  _buildActionButton(
                    context: context,
                    label: 'إكمال الطلب',
                    icon: Icons.task_alt_rounded,
                    backgroundColor: Colors.blue.shade600,
                    textColor: Colors.white,
                    isFullWidth: true,
                    onPressed: () => _updateRequestStatus(context, 'completed'),
                  ),
                  const SizedBox(height: 10),
                  _buildActionButton(
                    context: context,
                    label: 'حذف الطلب',
                    icon: Icons.delete_forever_rounded,
                    backgroundColor: Colors.transparent,
                    textColor: Colors.red.shade600,
                    borderColor: Colors.red.shade300,
                    isFullWidth: true,
                    onPressed: () => _deleteRequest(context),
                  ),
                ],
              ),
            ] else if (status == 'completed' || status == 'rejected') ...[
               _buildActionButton(
                    context: context,
                    label: 'حذف الطلب',
                    icon: Icons.delete_outline_rounded,
                    backgroundColor: Colors.grey.shade200,
                    textColor: Colors.red.shade700,
                    borderColor: Colors.grey.shade400,
                    isFullWidth: true,
                    onPressed: () => _deleteRequest(context),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMapOverlayButton(BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value, {Color? color}) {
    final ThemeData theme = Theme.of(context);
    if (value.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color ?? theme.colorScheme.primary),
        const SizedBox(width: 10),
        Text(
          label,
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: theme.textTheme.bodySmall?.color),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.textTheme.bodyMedium?.color),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(BuildContext context, IconData icon, String text, Color color) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required Color textColor,
    Color? borderColor,
    bool isFullWidth = false,
    required VoidCallback onPressed,
  }) {
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: textColor,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: borderColor != null ? BorderSide(color: borderColor) : BorderSide.none,
      ),
      elevation: backgroundColor == Colors.transparent ? 0 : 2,
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)
    );

    Widget button = ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: buttonStyle,
    );

    if (isFullWidth) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }
    return button;
  }

void _updateRequestStatus(BuildContext context, String newStatus) async {
  // Show loading indicator
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(child: CircularProgressIndicator()),
  );

  String successMessage = 'تم تحديث حالة الطلب بنجاح';
  Color snackbarColor = Colors.green; // Default to green for success

  try {
    final String requestId = requestData['id'] ?? '';
    if (requestId.isEmpty) {
      if (context.mounted) Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطأ: لا يمكن تحديث الطلب، معرف الطلب غير موجود'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    DocumentSnapshot? docSnapshot;
    docSnapshot = await FirebaseFirestore.instance.collection('serviceRequests').doc(requestId).get();
    if (!docSnapshot.exists) {
      docSnapshot = await FirebaseFirestore.instance.collection('service_requests').doc(requestId).get();
    }

    if (!docSnapshot.exists) {
      if (context.mounted) Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطأ: الطلب غير موجود أو تم حذفه'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    String collectionName = docSnapshot.reference.parent.id;
    Map<String, dynamic> updateData = {
      'status': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    };    if (newStatus == 'accepted') {
      updateData['isClientNotified'] = false;
      updateData['responseDate'] = FieldValue.serverTimestamp();
      updateData['hasUnreadNotification'] = true;
      updateData['lastStatusChangeBy'] = FirebaseAuth.instance.currentUser?.uid ?? '';
    }

    await FirebaseFirestore.instance.collection(collectionName).doc(requestId).update(updateData);

    // Notification Logic
    final String clientId = requestData['clientId'] ?? '';
    final String serviceId = requestData['serviceId'] ?? ''; // Used in notification data
    final String serviceNameData = requestData['serviceName'] ?? ''; // Used in notification data


    if (clientId.isNotEmpty) {
      final FcmService fcmService = FcmService();
      final NotificationService notificationService = NotificationService();
      
      try {
        // Try official notification service
        await notificationService.updateRequestStatus(
          requestId: requestId,
          status: newStatus,
          additionalMessage: null,
        );
        print('تم استخدام خدمة الإشعارات الرسمية لإرسال الإشعار');
      } catch (e) {
        print('خطأ في استخدام خدمة الإشعارات الرسمية: $e. جاري استخدام الإرسال اليدوي.');
        // Fallback to manual notification creation
        String title;
        String body;
        switch (newStatus) {
          case 'accepted':
            title = 'تم قبول طلبك';
            body = 'تم قبول طلب الخدمة الخاص بك "$serviceNameData"';
            break;
          case 'rejected':
            title = 'تم رفض طلبك';
            body = 'نعتذر، تم رفض طلب الخدمة الخاص بك "$serviceNameData"';
            break;
          case 'completed':
            title = 'تم إكمال طلبك';
            body = 'تم إكمال طلب الخدمة الخاص بك "$serviceNameData" بنجاح';
            break;
          default:
            title = 'تحديث حالة الطلب';
            body = 'تم تحديث حالة طلب الخدمة الخاص بك "$serviceNameData"';
        }

        try {
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': clientId,
            'title': title,
            'body': body,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
            'type': 'request_update',
            'data': {
              'requestId': requestId,
              'status': newStatus,
              'serviceId': serviceId,
              'serviceName': serviceNameData,
              'serviceType': requestData['serviceType'] ?? 'تخزين',
              'providerName': FirebaseAuth.instance.currentUser?.displayName ?? 'مزود الخدمة',
              'isForClient': true // Ensure this matches expected client-side logic
            },
          });
          await fcmService.sendNotificationToUser(
            userId: clientId,
            title: title,
            body: body,
            data: {
              'type': 'request_update',
              'requestId': requestId,
              'status': newStatus,
              'serviceId': serviceId,
              'serviceType': requestData['serviceType'] ?? 'تخزين',
              'targetScreen': 'client_interface', // Ensure this is handled by client
              'isForClient': 'true', // FCM data often stringifies booleans
               'userId': clientId
            },
          );
          print('تم إرسال الإشعار اليدوي بنجاح');
        } catch (manualNotificationError) {
          print('خطأ أثناء إرسال الإشعار اليدوي: $manualNotificationError');
          successMessage = 'تم تحديث الطلب، ولكن فشل إرسال الإشعار للعميل.';
          snackbarColor = Colors.orange; // Indicate partial success
        }
      }
    } else {
      successMessage = 'تم تحديث الطلب بنجاح (لا يوجد عميل لإشعاره).';
    }

    // Common success path: Close loading dialog and show success message
    if (context.mounted) {
      Navigator.of(context).pop(); 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: snackbarColor,
        ),
      );
      if (onRequestUpdated != null) {
        onRequestUpdated!();
      }
    }

  } catch (error) {
    print('Error updating request status: $error');
    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading dialog on error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء تحديث حالة الطلب: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}


  // فتح الخريطة لعرض موقع العميل داخل التطبيق
  void _openLocationInMaps(BuildContext context, GeoPoint? location, String label) async {
    try {
      if (location == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الموقع غير متوفر'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      if (context.mounted) Navigator.of(context).pop(); // Pop after ensuring context is still valid

      String locationNamePart = label; // Default to full label if no ' - '
      String locationAddressPart = '';

      if (label.contains(' - ')) {
        final parts = label.split(' - ');
        if (parts.length >= 2) {
            locationNamePart = parts[1]; // Text after ' - '
            locationAddressPart = parts[0]; // Text before ' - '
        }
      }


      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClientLocationMap(
              location: location,
              locationName: locationNamePart,
              locationAddress: locationAddressPart,
              isLiveLocation: label.contains('مباشر') || label.contains('الحالي'),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error opening location map: $e');
      // Ensure dialog is popped if it was shown and an error occurred before custom map navigation
      if (Navigator.of(context).canPop()) { // Check if a dialog or route is on top
         // Only pop if this was the loading dialog. Be cautious with generic pops.
         // A more robust way would be to use a flag or check the route name if possible.
         // For simplicity here, we assume it's our loading dialog.
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في فتح الخريطة: $e'),
          backgroundColor: Colors.red,
        ),
      );
      // Fallback to trying Google Maps URL (original logic)
      try {
        if (location != null) {
          final url = 'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}';
          // final url = 'https://www.google.com/maps/search/?api=1&query=$${location.latitude},${location.longitude}'; // Original URL
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            print('Could not launch $url');
             ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تعذر فتح تطبيق الخرائط الخارجية')),
             );
          }
        }
      } catch (e2) {
        print('Failed to open Google Maps as fallback: $e2');
      }
    }
  }

  // فتح تطبيق الخرائط للملاحة بين نقطة الانطلاق والوجهة
  void _openDirectionsInMaps(BuildContext context, GeoPoint? originLocation, GeoPoint? destinationLocation, String originName, String destinationName) async {
    try {
      if (originLocation == null || destinationLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('أحد المواقع غير متوفر، لا يمكن عرض المسار'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final url = 'https://www.google.com/maps/dir/?api=1&origin=${originLocation.latitude},${originLocation.longitude}&destination=${destinationLocation.latitude},${destinationLocation.longitude}&travelmode=driving';
      // final url = 'https://www.google.com/maps/dir/?api=1&origin=$${originLocation.latitude},${originLocation.longitude}&destination=${destinationLocation.latitude},${destinationLocation.longitude}'; // Original URL
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
         print('Could not launch $url');
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر فتح تطبيق الخرائط لعرض الاتجاهات')),
         );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء محاولة فتح خرائط جوجل: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // عرض خريطة كاملة الشاشة للموقع
  void _showClientLocationOnMap(BuildContext context, GeoPoint? clientLocation, String clientName, {bool showRoute = false, Map<String, dynamic>? data}) async {
    if (clientLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('بيانات الموقع غير متوفرة')),
      );
      return;
    }
    
    final String address = data?['clientAddress'] ?? (data?['address'] ?? ''); // Try both keys
    final String clientId = data?['clientId'] ?? '';

    if (showRoute) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      
      bool launched = false;
      // Try Google Maps directions URL first
      final mapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=${clientLocation.latitude},${clientLocation.longitude}&travelmode=driving';
      // final mapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=$${clientLocation.latitude},${clientLocation.longitude}&destination_name=${Uri.encodeComponent(clientName)}&travelmode=driving'; // Original URL
      final mapsUri = Uri.parse(mapsUrl);
      
      if (await canLaunchUrl(mapsUri)) {
        launched = await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
      }
      
      // Fallback to geo URI if Google Maps URL fails or isn't preferred for some reason
      if (!launched) {
        final geoUrl = 'geo:0,0?q=${clientLocation.latitude},${clientLocation.longitude}(${Uri.encodeComponent(clientName)})&mode=d'; // d for driving
        final geoUri = Uri.parse(geoUrl);
        if (await canLaunchUrl(geoUri)) {
          launched = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
        }
      }
      
      if (context.mounted) Navigator.pop(context); // Close loading dialog
      
      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لم يتم العثور على تطبيق خرائط يدعم الاتجاهات'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RequestLocationMap(
            location: clientLocation,
            title: 'موقع $clientName',
            address: address, 
            enableNavigation: true, // Allows user to start navigation from the map screen
            clientId: clientId.isNotEmpty ? clientId : null,
            showRouteToCurrent: false, // This screen will show the point, navigation can be initiated from it
          ),
        ),
      );
    }
  }

  // Show the full-screen map for transport requests (origin and destination)
  void _showFullMap(BuildContext context) {
    if (requestData['serviceType'] == 'نقل') {
      final GeoPoint? originLocation = requestData['originLocation'] as GeoPoint?;
      final GeoPoint? destinationLocation = requestData['destinationLocation'] as GeoPoint?;

      if (originLocation != null && destinationLocation != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FullScreenMap(
              originLocation: originLocation,
              destinationLocation: destinationLocation,
              originName: requestData['originName'] ?? '',
              destinationName: requestData['destinationName'] ?? '',
              distanceText: requestData['distanceText'] ?? '',
              durationText: requestData['durationText'] ?? '',
            ),
          ),
        );
      } else {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('بيانات موقع الانطلاق أو الوجهة غير مكتملة لعرض الخريطة الكاملة.')),
        );
      }
    }
  }

  // Enviar solicitud de ubicación al cliente
  void _sendLocationRequest(BuildContext context, String clientId, String clientName) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final fcmService = FcmService();
      final String requestId = requestData['id'] ?? '';
      final String serviceId = requestData['serviceId'] ?? '';

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': clientId,
        'title': 'طلب الموقع',
        'body': 'مزود الخدمة يطلب موقعك الحالي لتقديم الخدمة',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'location_request', // Ensure client handles this type
        'data': {
          'requestId': requestId,
          'serviceId': serviceId,
          // Add any other relevant data client might need
        },
      });

      await fcmService.sendNotificationToUser(
        userId: clientId,
        title: 'طلب الموقع',
        body: 'مزود الخدمة "$clientName" يطلب موقعك الحالي لتقديم الخدمة', // Provider name can be useful
        data: {
          'type': 'location_request',
          'requestId': requestId,
          'serviceId': serviceId,
          // 'providerName': FirebaseAuth.instance.currentUser?.displayName ?? 'مزود الخدمة', // If needed by client
          'targetScreen': 'location_sharing_prompt', // Example: client navigates here
        },
      );

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال طلب الموقع إلى العميل'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error sending location request: $e');
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء إرسال طلب الموقع: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Add a button to directly show the route to bottom of card when client location is available
  Widget _buildRouteButton(BuildContext context, GeoPoint? clientLocation, String clientName) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _openRouteToClient(context, clientLocation, clientName),
        icon: const Icon(Icons.directions_car_rounded, size: 18),
        label: const Text('تتبع المسار إلى العميل', style: TextStyle(fontSize: 13)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  // Add this method to handle direct route navigation from current to client location
  void _openRouteToClient(BuildContext context, GeoPoint? clientLocation, String clientName) {
    _showClientLocationOnMap(context, clientLocation, clientName, showRoute: true, data: requestData);
  }

  // حذف الطلب
  Future<void> _deleteRequest(BuildContext context) async {
    // Store the context reference before any async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    
    // عرض مربع حوار تأكيد قبل الحذف
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'تأكيد الحذف',
          style: TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.right,
        ),
        content: const Text(
          'هل أنت متأكد من أنك تريد حذف هذا الطلب؟ لا يمكن التراجع عن هذا الإجراء.',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
        actionsAlignment: MainAxisAlignment.start,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ) ?? false;

    if (!confirmDelete) return;

    if (!context.mounted) return;
    
    // عرض مؤشر التحميل
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {      final String requestId = requestData['id'] ?? '';
      if (requestId.isEmpty) {
        if (!context.mounted) return;
        
        Navigator.of(context).pop(); // إغلاق مؤشر التحميل
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ: لا يمكن حذف الطلب، معرف الطلب غير موجود'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // التحقق من وجود الطلب في أي من المجموعات
      DocumentSnapshot? docSnapshot;
      docSnapshot = await FirebaseFirestore.instance.collection('serviceRequests').doc(requestId).get();
      if (!docSnapshot.exists) {
        docSnapshot = await FirebaseFirestore.instance.collection('service_requests').doc(requestId).get();
      }      if (!docSnapshot.exists) {
        if (!context.mounted) return;
        
        Navigator.of(context).pop(); // إغلاق مؤشر التحميل
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ: الطلب غير موجود أو تم حذفه مسبقاً'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // حذف الطلب من قاعدة البيانات
      String collectionName = docSnapshot.reference.parent.id;
      await FirebaseFirestore.instance.collection(collectionName).doc(requestId).delete();

      // إغلاق مؤشر التحميل وإظهار رسالة نجاح
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الطلب بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        
        // إخطار الشاشة الأم بتحديث القائمة
        if (onRequestUpdated != null) {
          onRequestUpdated!();
        }
      }
      
    } catch (error) {
      print('Error deleting request: $error');
      if (context.mounted) {
        Navigator.of(context).pop(); // إغلاق مؤشر التحميل عند حدوث خطأ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء حذف الطلب: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
