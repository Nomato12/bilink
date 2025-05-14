import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:bilink/screens/client_details_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:bilink/services/fcm_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bilink/screens/full_screen_map.dart';
import 'package:bilink/screens/request_location_map.dart';
import 'package:bilink/utils/location_helper.dart';

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
    // Extract data from the request
    final String status = requestData['status'] ?? 'pending';
    final String serviceName = requestData['serviceName'] ?? 'خدمة';
    final String clientName = requestData['clientName'] ?? 'عميل';
    final String details = requestData['details'] ?? '';
    final String serviceType = requestData['serviceType'] ?? 'تخزين';
    final Timestamp? createdAt = requestData['createdAt'] as Timestamp?;
    
    // Get client location using helper
    GeoPoint? clientLocation = LocationHelper.getLocationFromData(requestData);
    String clientAddress = LocationHelper.getAddressFromData(requestData);
    bool isLiveLocation = LocationHelper.isLocationRecent(requestData);
    
    // Transport-specific data
    final GeoPoint? originLocation = requestData['originLocation'] as GeoPoint?;
    final GeoPoint? destinationLocation = requestData['destinationLocation'] as GeoPoint?;
    final String originName = requestData['originName'] ?? '';
    final String destinationName = requestData['destinationName'] ?? '';
    final String distanceText = requestData['distanceText'] ?? '';
    final String durationText = requestData['durationText'] ?? '';
    final String vehicleType = requestData['vehicleType'] ?? '';
    final double price = (requestData['price'] ?? 0).toDouble();
    
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.5), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service name and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Show service type indicator
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: serviceType == 'نقل' 
                              ? Colors.blue.withOpacity(0.1) 
                              : Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: serviceType == 'نقل' ? Colors.blue : Colors.teal,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          serviceType == 'نقل' ? 'خدمة نقل' : 'خدمة تخزين',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: serviceType == 'نقل' ? Colors.blue : Colors.teal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Status chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor, width: 1),
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
            
            // Client name and creation date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 18, color: Colors.grey),
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
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Botón para buscar la ubicación del cliente y navegar                      if (status == 'accepted')
                        InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ClientDetailsScreen(
                                clientId: requestData['clientId'] ?? '',
                              ),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green, width: 1),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on, size: 14, color: Colors.green),
                                SizedBox(width: 4),
                                Text(
                                  'موقع العميل',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.date_range, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      formattedCreatedAt,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            // Show transport-specific details for transport service
            if (serviceType == 'نقل' && originLocation != null && destinationLocation != null) ...[
              const SizedBox(height: 16),              // Map view
              GestureDetector(
                onTap: () => _showFullMap(context),
                child: Container(
                  height: 150,
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
                        ),                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: Colors.black.withOpacity(0.6),
                            padding: const EdgeInsets.symmetric(vertical: 6),                          
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                InkWell(
                                  onTap: () => _openLocationInMaps(context, originLocation, 'نقطة الانطلاق: $originName'),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.trip_origin, color: Colors.white, size: 16),
                                      SizedBox(width: 4),
                                      Text(
                                        'ملاحة للانطلاق',
                                        style: TextStyle(color: Colors.white, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _openLocationInMaps(context, destinationLocation, 'الوجهة: $destinationName'),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.location_on, color: Colors.white, size: 16),
                                      SizedBox(width: 4),
                                      Text(
                                        'ملاحة للوجهة',
                                        style: TextStyle(color: Colors.white, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _openDirectionsInMaps(context, originLocation, destinationLocation, originName, destinationName),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.directions, color: Colors.white, size: 16),
                                      SizedBox(width: 4),
                                      Text(
                                        'مسار كامل',
                                        style: TextStyle(color: Colors.white, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),                        Positioned(
                          top: 8,
                          right: 8,
                          child: Tooltip(
                            message: 'فتح الخريطة بشكل كامل',
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(
                                Icons.fullscreen,
                                color: Colors.blue,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Transport details
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // Origin and destination
                    Row(
                      children: [
                        Icon(Icons.trip_origin, size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'من: $originName',
                            style: const TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'إلى: $destinationName',
                            style: const TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Distance, duration and price
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.route, size: 16, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(distanceText, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 16, color: Colors.orange),
                            const SizedBox(width: 4),
                            Text(durationText, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.local_shipping, size: 16, color: Colors.purple),
                            const SizedBox(width: 4),
                            Text(vehicleType, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Price
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          'السعر: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$price دج',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            fontSize: 16,
                          ),
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section title
                    const Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.green, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'موقع العميل',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (clientLocation != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (clientAddress.isNotEmpty)
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_city, color: Colors.grey, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      clientAddress,
                                      style: const TextStyle(fontSize: 13),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (isLiveLocation) ...[
                            const SizedBox(width: 8),
                            Tooltip(
                              message: 'موقع مباشر',
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.gps_fixed, color: Colors.white, size: 12),
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
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _showClientLocationOnMap(context, clientLocation, clientName),
                        child: Container(
                          height: 100,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              children: [
                                GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: LatLng(clientLocation.latitude, clientLocation.longitude),
                                    zoom: 14.0,
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
                                    color: Colors.black.withOpacity(0.5),
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                    child: const Text(
                                      'انقر لفتح الخريطة',
                                      style: TextStyle(color: Colors.white, fontSize: 10),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showClientLocationOnMap(context, clientLocation, clientName),
                              icon: const Icon(Icons.map, size: 16),
                              label: const Text('عرض الخريطة', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showClientLocationOnMap(context, clientLocation, clientName, showRoute: true),
                              icon: const Icon(Icons.route, size: 16),
                              label: const Text('المسار', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.purple,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _openLocationInMaps(
                                context, 
                                clientLocation, 
                                'موقع $clientName - ${clientAddress.isNotEmpty ? clientAddress : ''}'
                              ),
                              icon: const Icon(Icons.directions, size: 16),
                              label: const Text('الملاحة', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),                      const SizedBox(height: 8),
                      _buildRouteButton(context, clientLocation, clientName),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(                          onPressed: () {
                            // عرض رسالة منبثقة في حالة عدم وجود موقع متاح
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('موقع العميل غير متوفر'),
                                content: const Text('لم يتم العثور على بيانات موقع لهذا العميل.\nهل تريد الانتقال إلى صفحة تفاصيل العميل؟'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('إلغاء'),
                                  ),
                                  TextButton(
                                    onPressed: () => _sendLocationRequest(context, requestData['clientId'] ?? '', clientName),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                    ),
                                    child: const Text('طلب الموقع'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ClientDetailsScreen(
                                            clientId: requestData['clientId'] ?? '',
                                            showDestinationDirectly: true,
                                          ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade700,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('نعم، انتقل للتفاصيل'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.location_on, size: 16),
                          label: const Text('عرض الموقع'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.green.shade700,
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  details,
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
            
            const SizedBox(height: 16),
            
            // Action buttons based on status
            if (status == 'pending') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: _buildActionButton(
                      context: context,
                      label: 'قبول',
                      icon: Icons.check_circle,
                      color: Colors.green,
                      onPressed: () => _updateRequestStatus(context, 'accepted'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      context: context,
                      label: 'رفض',
                      icon: Icons.cancel,
                      color: Colors.red,
                      onPressed: () => _updateRequestStatus(context, 'rejected'),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'accepted') ...[
              _buildActionButton(
                context: context,
                label: 'إكمال الطلب',
                icon: Icons.done_all,
                color: Colors.blue,
                onPressed: () => _updateRequestStatus(context, 'completed'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withOpacity(0.5)),
        ),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
    );
  }

  void _updateRequestStatus(BuildContext context, String newStatus) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );      // Get the request ID
      final String requestId = requestData['id'] ?? '';
      if (requestId.isEmpty) {
        // Close loading dialog
        Navigator.of(context).pop();
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: لا يمكن تحديث الطلب، معرف الطلب غير موجود'),
            backgroundColor: Colors.red,
          ),
        );
        return; // Exit early
      }      // Try to find the document in both possible collections
      DocumentSnapshot? docSnapshot;
      
      // First, try the serviceRequests collection
      docSnapshot = await FirebaseFirestore.instance
          .collection('serviceRequests')
          .doc(requestId)
          .get();
      
      // If not found, try the service_requests collection
      if (!docSnapshot.exists) {
        docSnapshot = await FirebaseFirestore.instance
            .collection('service_requests')
            .doc(requestId)
            .get();
      }
      
      if (!docSnapshot.exists) {
        // Close loading dialog
        if (context.mounted) {
          Navigator.of(context).pop();
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ: الطلب غير موجود أو تم حذفه'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return; // Exit early
      }      try {
        // Update request status in Firestore using the collection where it was found
        String collectionName = docSnapshot.reference.parent.id;
        
        await FirebaseFirestore.instance
            .collection(collectionName)
            .doc(requestId)
            .update({
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (updateError) {
        print('Error updating request status: $updateError');
        if (context.mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل تحديث حالة الطلب: $updateError'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return; // Exit early
      }// Send notification to the client
      final fcmService = FcmService();
      final String clientId = requestData['clientId'] ?? '';
      
      if (clientId.isNotEmpty) {
        String title;
        String body;
        
        switch (newStatus) {
          case 'accepted':
            title = 'تم قبول طلبك';
            body = 'تم قبول طلب الخدمة الخاص بك';
            break;
          case 'rejected':
            title = 'تم رفض طلبك';
            body = 'نعتذر، تم رفض طلب الخدمة الخاص بك';
            break;
          case 'completed':
            title = 'تم إكمال طلبك';
            body = 'تم إكمال طلب الخدمة الخاص بك بنجاح';
            break;
          default:
            title = 'تحديث حالة الطلب';
            body = 'تم تحديث حالة طلب الخدمة الخاص بك';
        }
        
        try {
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': clientId,
            'title': title,
            'body': body,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
            'type': 'service_request_update',
            'requestId': requestId,
          });
          
          // Try to send FCM notification
          try {
            await fcmService.sendNotificationToUser(
              userId: clientId,
              title: title,
              body: body,
              data: {
                'type': 'request_update',
                'requestId': requestId,
                'status': newStatus
              },
            );
          } catch (fcmError) {
            print('Error sending FCM notification: $fcmError');
          }
        } catch (notificationError) {
          print('Error adding notification: $notificationError');
        }
      }      // Close loading indicator
      if (context.mounted) {
        Navigator.pop(context);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث حالة الطلب بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Notify parent widget to refresh
        if (onRequestUpdated != null) {
          onRequestUpdated!();
        }
      }} catch (e) {
      // Close loading indicator
      if (context.mounted) {
        Navigator.pop(context);
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تحديث حالة الطلب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error updating request status: $e');
    }
  }
  // فتح تطبيق الخرائط للملاحة إلى الموقع
  void _openLocationInMaps(BuildContext context, GeoPoint location, String label) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      final url = 'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}';
      final uri = Uri.parse(url);
      bool launched = false;

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        launched = true;
      }
      if (!launched) {
        final geoUri = Uri.parse('geo:${location.latitude},${location.longitude}?q=${Uri.encodeComponent(label)}');
        if (await canLaunchUrl(geoUri)) {
          await launchUrl(geoUri, mode: LaunchMode.externalApplication);
          launched = true;
        }
      }
      if (!launched) {
        final appleMapsUrl = Uri.parse('http://maps.apple.com/?q=${location.latitude},${location.longitude}');
        if (await canLaunchUrl(appleMapsUrl)) {
          await launchUrl(appleMapsUrl, mode: LaunchMode.externalApplication);
          launched = true;
        }
      }
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  // فتح تطبيق الخرائط للملاحة بين نقطة الانطلاق والوجهة
  void _openDirectionsInMaps(BuildContext context, GeoPoint originLocation, GeoPoint destinationLocation, String originName, String destinationName) async {
    try {
      final url = 'https://www.google.com/maps/dir/?api=1&origin=${originLocation.latitude},${originLocation.longitude}'
          '&destination=${destinationLocation.latitude},${destinationLocation.longitude}';
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Handle error if needed
    }  }
  
  // عرض خريطة كاملة الشاشة للموقع
  void _showClientLocationOnMap(BuildContext context, GeoPoint clientLocation, String clientName, {bool showRoute = false}) async {
    try {
      final String address = requestData['clientAddress'] ?? '';
      final String clientId = requestData['clientId'] ?? '';
      
      if (showRoute) {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
        
        // Try to open in Google Maps with directions
        final url = 'https://www.google.com/maps/dir/?api=1&destination=${clientLocation.latitude},${clientLocation.longitude}&destination_name=${Uri.encodeComponent(clientName)}&travelmode=driving';
        final uri = Uri.parse(url);
        
        bool launched = false;
        
        if (await canLaunchUrl(uri)) {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        
        // Try alternative URI format if the first one fails
        if (!launched) {
          final geoUrl = 'geo:0,0?q=${clientLocation.latitude},${clientLocation.longitude}(${Uri.encodeComponent(clientName)})&mode=d';
          final geoUri = Uri.parse(geoUrl);
          
          if (await canLaunchUrl(geoUri)) {
            launched = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
          }
        }
        
        // Close loading dialog
        if (context.mounted) {
          Navigator.pop(context);
          
          // Show message if failed
          if (!launched) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('لم يتم العثور على تطبيق خرائط يدعم الاتجاهات'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        // Just show the map without directions
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RequestLocationMap(
              location: clientLocation,
              title: 'موقع $clientName',
              address: address, 
              enableNavigation: true,
              clientId: clientId.isNotEmpty ? clientId : null,
              showRouteToCurrent: showRoute,
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if it's open
      if (context.mounted) {
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء محاولة فتح الخريطة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  // Show the full-screen map
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
      }
    }
  }

  // Buscar y navegar a la ubicación del cliente
  void _fetchAndNavigateToClientLocation(BuildContext context, String clientId) async {
    try {
      if (clientId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('معرّف العميل غير متوفر'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Buscar la información del cliente en Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(clientId)
          .get();
      
      // Cerrar el indicador de carga
      if (context.mounted) {
        Navigator.pop(context);
      }
      
      if (!userDoc.exists) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يمكن العثور على معلومات العميل'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;      
      // Comprobar si hay datos de ubicación
      GeoPoint? clientLocation;
      String locationAddress = 'موقع العميل';
      bool isLiveLocation = false;
      Timestamp? locationTimestamp;
      
      // Intentar obtener la ubicación del usuario desde diferentes campos
      if (userData.containsKey('location') && userData['location'] is Map<String, dynamic>) {
        final locationData = userData['location'] as Map<String, dynamic>;
        if (locationData.containsKey('latitude') && locationData.containsKey('longitude')) {
          clientLocation = GeoPoint(
            locationData['latitude'] as double,
            locationData['longitude'] as double,
          );
          
          if (locationData.containsKey('address') && locationData['address'] is String) {
            locationAddress = locationData['address'] as String;
          }
          
          if (locationData.containsKey('timestamp') && locationData['timestamp'] is Timestamp) {
            locationTimestamp = locationData['timestamp'] as Timestamp;
            final DateTime now = DateTime.now();
            final DateTime locationTime = locationTimestamp.toDate();
            // Check if the location is recent (within the last 10 minutes)
            if (now.difference(locationTime).inMinutes < 10) {
              isLiveLocation = true;
            }
          }
        }
      } else if (userData.containsKey('lastLocation') && userData['lastLocation'] is GeoPoint) {
        clientLocation = userData['lastLocation'] as GeoPoint;
        
        if (userData.containsKey('lastLocationTimestamp') && userData['lastLocationTimestamp'] is Timestamp) {
          locationTimestamp = userData['lastLocationTimestamp'] as Timestamp;
          final DateTime now = DateTime.now();
          final DateTime locationTime = locationTimestamp.toDate();
          // Check if the location is recent (within the last 10 minutes)
          if (now.difference(locationTime).inMinutes < 10) {
            isLiveLocation = true;
          }
        }
      } else if (userData.containsKey('homeLocation') && userData['homeLocation'] is GeoPoint) {
        clientLocation = userData['homeLocation'] as GeoPoint;
        locationAddress = 'عنوان العميل';
      }      if (clientLocation == null) {
        if (context.mounted) {
          // Mostrar diálogo para solicitar al cliente su ubicación
          _showRequestLocationDialog(context, clientId, userData['displayName'] ?? 'العميل');
        }
        return;
      }
      
      // Show dialog with options to view on map or navigate
      if (context.mounted) {
        _showLocationOptionsDialog(
          context, 
          clientLocation, 
          userData['displayName'] ?? 'العميل', 
          locationAddress,
          isLiveLocation: isLiveLocation,
          locationTimestamp: locationTimestamp
        );
      }
    } catch (e) {
      print('Error fetching client location: $e');
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Cerrar el diálogo si está abierto
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء محاولة الوصول إلى موقع العميل: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Mostrar diálogo para solicitar la ubicación del cliente
  void _showRequestLocationDialog(BuildContext context, String clientId, String clientName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('موقع العميل غير متوفر'),
        content: Text('لم نتمكن من العثور على موقع $clientName. هل تريد إرسال طلب للحصول على موقعه الحالي؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendLocationRequest(context, clientId, clientName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('طلب الموقع'),
          ),
        ],
      ),
    );
  }
  
  // Enviar solicitud de ubicación al cliente
  void _sendLocationRequest(BuildContext context, String clientId, String clientName) async {
    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Enviar notificación al cliente solicitando su ubicación
      final fcmService = FcmService();
      
      // Crear notificación en Firestore
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': clientId,
        'title': 'طلب الموقع',
        'body': 'مزود الخدمة يطلب موقعك الحالي لتقديم الخدمة',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'location_request',
        'data': {
          'requestId': requestData['id'] ?? '',
          'serviceId': requestData['serviceId'] ?? '',
        },
      });
      
      // Enviar notificación FCM
      try {
        await fcmService.sendNotificationToUser(
          userId: clientId,
          title: 'طلب الموقع',
          body: 'مزود الخدمة يطلب موقعك الحالي لتقديم الخدمة',
          data: {
            'type': 'location_request',
            'requestId': requestData['id'] ?? '',
          },
        );
      } catch (fcmError) {
        print('Error sending FCM notification: $fcmError');
      }
      
      // Cerrar el indicador de carga
      if (context.mounted) {
        Navigator.pop(context);
        
        // Mostrar mensaje de éxito
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
        Navigator.pop(context); // Cerrar el diálogo de carga
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء إرسال طلب الموقع: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }  // Show dialog with options for client location
  void _showLocationOptionsDialog(BuildContext context, GeoPoint location, String clientName, String address, {bool isLiveLocation = false, Timestamp? locationTimestamp}) {
    String locationInfo = address.isNotEmpty ? 'العنوان: $address' : '';
    
    if (locationTimestamp != null) {
      final dateFormat = DateFormat('yyyy/MM/dd hh:mm a');
      final formattedTime = dateFormat.format(locationTimestamp.toDate());
      locationInfo += locationInfo.isNotEmpty ? '\n' : '';
      locationInfo += 'وقت تحديث الموقع: $formattedTime';
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.green),
            const SizedBox(width: 8),
            Text('موقع $clientName'),
            if (isLiveLocation) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.gps_fixed, color: Colors.white, size: 12),
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (locationInfo.isNotEmpty) ...[
              Text(locationInfo),
              const SizedBox(height: 16),
            ],
            const Text('ماذا تريد أن تفعل؟'),
          ],
        ),
        actions: [          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showClientLocationOnMap(context, location, clientName);
            },
            icon: const Icon(Icons.map),
            label: const Text('عرض على الخريطة'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showClientLocationOnMap(context, location, clientName, showRoute: true);
            },
            icon: const Icon(Icons.route),
            label: const Text('عرض المسار'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _openLocationInMaps(context, location, '$address - $clientName');
            },
            icon: const Icon(Icons.directions),
            label: const Text('الملاحة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Add this method to handle direct route navigation from current to client location
  void _openRouteToClient(BuildContext context, GeoPoint clientLocation, String clientName) {
    _showClientLocationOnMap(context, clientLocation, clientName, showRoute: true);
  }

  // Add a button to directly show the route to bottom of card when client location is available
  Widget _buildRouteButton(BuildContext context, GeoPoint clientLocation, String clientName) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      child: ElevatedButton.icon(
        onPressed: () => _openRouteToClient(context, clientLocation, clientName),
        icon: const Icon(Icons.route, size: 16),
        label: const Text('عرض المسار من موقعك', style: TextStyle(fontSize: 13)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 36),
        ),
      ),
    );
  }
}
