import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for Clipboard
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart'; // Added for location services
import 'package:bilink/screens/client_details_screen.dart';
import 'package:bilink/services/notification_service.dart';
import 'package:bilink/services/fcm_service.dart';
import 'package:bilink/screens/request_location_map.dart';
import 'package:bilink/screens/directions_map_tracking.dart';
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
    // Define a primary color for consistent theming
    final Color primaryColor = const Color(0xFF7B1FA2); // Vibrant Purple
    final Color darkerPrimaryShade = const Color(0xFF4A148C); // Darker Purple for accents/text
    final Color lightPrimaryColor = primaryColor.withOpacity(0.1);    // Extract data from the request
    final String status = requestData['status'] ?? 'pending';
    final String serviceName = requestData['serviceName'] ?? 'خدمة نقل';
    final String clientName = requestData['clientName'] ?? 'عميل';
    // Details are accessed directly where needed
    final Timestamp? createdAt = requestData['createdAt'] as Timestamp?;
    
    // Transport-specific data
    final GeoPoint? originLocation = requestData['originLocation'] as GeoPoint?;
    final GeoPoint? destinationLocation = requestData['destinationLocation'] as GeoPoint?;
    final String originName = requestData['originName'] ?? '';
    final String destinationName = requestData['destinationName'] ?? '';
    final String distanceText = requestData['distanceText'] ?? '';
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
        ? DateFormat('yyyy/MM/dd hh:mm a', 'ar').format(createdAt.toDate())
        : 'غير معروف';

    // Define colors based on status
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'accepted':
        statusColor = Colors.green.shade600;
        statusText = 'تم القبول';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        statusColor = Colors.red.shade600;
        statusText = 'تم الرفض';
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = Colors.orange.shade600;
        statusText = 'قيد الانتظار';
        statusIcon = Icons.hourglass_top_rounded;
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
    
    // Calculate map bounds done dynamically in the map component
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.2), // Updated shadow
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 5), // Slightly adjusted offset
          ),
        ],
        border: Border.all(
          color: statusColor.withOpacity(0.7), // Updated border opacity
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showRequestDetails(context, primaryColor, darkerPrimaryShade), // Pass darker shade
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Enhanced header with service name and status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: lightPrimaryColor, // Updated
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.local_shipping_rounded, // Updated icon
                              color: primaryColor, // Updated
                              size: 24, // Slightly larger icon
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              serviceName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18, // Increased font size
                                color: darkerPrimaryShade, // Updated color
                                letterSpacing: 0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
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
                // Enhanced price section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, darkerPrimaryShade], // Updated gradient
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.4), // Updated shadow
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
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
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.account_balance_wallet_rounded,
                                  color: Colors.white.withOpacity(0.85), // Updated icon color
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'سعر الخدمة:',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9), // Updated text color
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                ServiceVehiclesHelper.formatPrice(price).split(' ')[0],
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 26, // Increased font size
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'دج',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Client name and time
                Row(
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 18,
                      color: primaryColor.withOpacity(0.8), // Updated color
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'العميل: $clientName',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade900, // Darker text
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.schedule_rounded,
                      size: 18,
                      color: primaryColor.withOpacity(0.8), // Updated color
                    ),
                    const SizedBox(width: 6),
                    Text(
                      formattedCreatedAt,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade900, // Darker text
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Transport route info
                if (originName.isNotEmpty || destinationName.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.06), // Updated background
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Origin
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.my_location_rounded, // Updated icon
                                size: 16,
                                color: Colors.green.shade700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                originName.isNotEmpty ? originName : 'نقطة الانطلاق',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (originName.isNotEmpty && destinationName.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
                            child: CustomPaint(
                              size: const Size(2, 20),
                              painter: _DashedLinePainter(color: primaryColor.withOpacity(0.5)), // Updated color
                            ),
                          ),
                        // Destination
                        if (destinationName.isNotEmpty)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.location_on_rounded, // Updated icon
                                  size: 16,
                                  color: Colors.red.shade700,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  destinationName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        // Distance and duration info
                        if (distanceText.isNotEmpty || durationText.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: primaryColor.withOpacity(0.3)) // Updated border
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (distanceText.isNotEmpty) ...[
                                  Icon(
                                    Icons.linear_scale_rounded,
                                    size: 16,
                                    color: primaryColor, // Updated color
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    distanceText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: primaryColor, // Updated color
                                    ),
                                  ),
                                  if (durationText.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                      child: Text("•", style: TextStyle(color: primaryColor.withOpacity(0.5))), // Updated color
                                    ),
                                ],
                                if (durationText.isNotEmpty) ...[
                                  Icon(
                                    Icons.timer_rounded,
                                    size: 16,
                                    color: primaryColor, // Updated color
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    durationText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: primaryColor, // Updated color
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                // Action buttons
                Wrap(
                  alignment: WrapAlignment.center, // Center align buttons
                  spacing: 10, // Spacing between buttons
                  runSpacing: 10, // Spacing between rows of buttons
                  children: [
                    // Client details button
                    _buildActionButton(
                      context,
                      primaryColor: primaryColor,
                      icon: Icons.account_circle_rounded, // Updated icon
                      label: 'بيانات العميل',
                      onPressed: () => _viewClientDetails(context),
                    ),
                      // Map button with directions indication
                    if (originLocation != null && destinationLocation != null)
                      _buildActionButton(
                        context,
                        primaryColor: primaryColor,
                        icon: Icons.directions, // Changed to directions icon to indicate navigation
                        label: 'الملاحة للعميل',
                        onPressed: () => _viewOnMap(context),
                      ),                      // New navigation button with turn-by-turn directions
                    if (originLocation != null && destinationLocation != null)
                      _buildActionButton(
                        context,
                        primaryColor: primaryColor,
                        icon: Icons.map_outlined, // Changed icon to map
                        label: 'الملاحة لوجهة العميل', // Clearer label for client destination
                        onPressed: () => _navigateWithDirections(context),
                      ),
                    
                    // Call client button
                    _buildActionButton(
                      context,
                      primaryColor: primaryColor,
                      icon: Icons.phone_rounded, // Updated icon
                      label: 'اتصال',
                      onPressed: () => _callClient(context),
                    ),
                  ],                ),
                
                // Request status actions based on status
                Padding(                  padding: const EdgeInsets.only(top: 16),
                  child: status == 'pending' 
                    ? Row(
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
                      )
                    : status == 'accepted'
                      ? Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _completeRequest(context),
                                icon: const Icon(Icons.task_alt_rounded, color: Colors.white),
                                label: const Text('إكمال الطلب', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade600,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _deleteRequest(context),
                                icon: Icon(Icons.delete_forever_rounded, color: Colors.red.shade600),
                                label: Text('حذف الطلب', style: TextStyle(color: Colors.red.shade600)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  side: BorderSide(color: Colors.red.shade300),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Container(), // Empty container for other status values
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
    required Color primaryColor,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: primaryColor), // Updated
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: primaryColor, // Updated
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor.withOpacity(0.1), // Updated
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), // Adjusted padding
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: BorderSide(color: primaryColor.withOpacity(0.4)), // Updated
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
  // View and navigate to client location using your current location
void _viewOnMap(BuildContext context) {
    // Get client location from request data
    final GeoPoint? clientLocation = requestData['originLocation'] as GeoPoint?;
    final GeoPoint? destinationLocation = requestData['destinationLocation'] as GeoPoint?;
    final String clientId = requestData['clientId'] ?? '';
    
    if (clientLocation != null) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Get current location permission and navigate to map
      Geolocator.requestPermission().then((permission) {
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          if (context.mounted) {
            Navigator.pop(context); // Close loading dialog
            _showErrorSnackBar(context, 'يجب السماح بالوصول إلى موقعك لاستخدام الملاحة');
          }
          return;
        }
        
        // Close loading dialog and navigate to map
        if (context.mounted) {
          // Get shortened client name to avoid overflow
          String clientName = requestData['clientName'] ?? 'العميل';
          if (clientName.length > 15) {
            clientName = '${clientName.substring(0, 12)}...';
          }
          
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RequestLocationMap(
                location: clientLocation, // Client location as the main location
                title: 'موقع العميل: $clientName',
                destinationLocation: destinationLocation,
                destinationName: requestData['destinationName'] ?? 'الوجهة',
                address: requestData['originAddress'] ?? '',
                enableNavigation: true,
                showRouteToCurrent: true, // This will show route from provider to client
                requestId: requestData['id'],
                clientId: clientId, // Pass client ID for real-time tracking if available
              ),
            ),
          );
        }
      }).catchError((error) {
        if (context.mounted) {
          Navigator.pop(context); // Close loading dialog
          _showErrorSnackBar(context, 'حدث خطأ أثناء الحصول على الموقع: $error');
        }
      });
    } else {
      _showErrorSnackBar(context, 'معلومات موقع العميل غير متوفرة');
    }
  }
  // Navigate with turn-by-turn directions and real-time tracking
  void _navigateWithDirections(BuildContext context) {
    final GeoPoint? originLocation = requestData['originLocation'] as GeoPoint?;
    final GeoPoint? destinationLocation = requestData['destinationLocation'] as GeoPoint?;
    
    if (originLocation != null && destinationLocation != null) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Get current location permission
      Geolocator.requestPermission().then((permission) {
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          if (context.mounted) {
            Navigator.pop(context); // Close loading dialog
            _showErrorSnackBar(context, 'يجب السماح بالوصول إلى موقعك لاستخدام الملاحة المباشرة');
          }
          return;
        }
        
        // Get the current position to start navigation from current location
        Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
            .then((position) {
          if (context.mounted) {
            Navigator.pop(context); // Close loading dialog
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LiveTrackingMapScreen(
                  originLocation: LatLng(position.latitude, position.longitude), // Use current real position
                  originName: 'موقعي الحالي',
                  destinationLocation: LatLng(destinationLocation.latitude, destinationLocation.longitude),
                  destinationName: requestData['destinationName'] ?? 'وجهة العميل',
                ),
              ),
            );
          }
        }).catchError((error) {
          if (context.mounted) {
            Navigator.pop(context); // Close loading dialog
            _showErrorSnackBar(context, 'حدث خطأ أثناء تحديد موقعك: $error');
          }
        });
      });
    } else {
      _showErrorSnackBar(context, 'معلومات الموقع غير متوفرة للملاحة');
    }
  }  
  // فتح الملاحة المتقدمة في تطبيق Google Maps للمسافات الطويلة
  void _openAdvancedNavigation(BuildContext context) {
    final GeoPoint? destinationLocation = requestData['destinationLocation'] as GeoPoint?;
    
    if (destinationLocation == null) {
      _showErrorSnackBar(context, 'معلومات وجهة العميل غير متاحة');
      return;
    }

    // عرض مؤشر التحميل
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    // الحصول على الموقع الحالي
    Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
      .then((position) {
        if (!context.mounted) return;
        
        // إغلاق مؤشر التحميل
        Navigator.pop(context);
        
        // بناء رابط لفتح الملاحة في تطبيق خرائط Google
        final url = 'https://www.google.com/maps/dir/?api=1'
            '&origin=${position.latitude},${position.longitude}'
            '&destination=${destinationLocation.latitude},${destinationLocation.longitude}'
            '&travelmode=driving';
            
        final uri = Uri.parse(url);
        
        // فتح تطبيق الخرائط
        launchUrl(uri, mode: LaunchMode.externalApplication).then((launched) {
          if (!launched && context.mounted) {
            _showErrorSnackBar(context, 'لا يمكن فتح تطبيق الخرائط، تأكد من تثبيته على جهازك');
          }
        });
      })
      .catchError((error) {
        if (context.mounted) {
          Navigator.pop(context); // إغلاق مؤشر التحميل
          _showErrorSnackBar(context, 'حدث خطأ أثناء تحديد موقعك: $error');
        }
      });
  }
  // Call client - enhanced with clipboard copy option
  void _callClient(BuildContext context) async {
    final String clientPhone = requestData['clientPhone'] ?? '';
    final Color primaryColor = const Color(0xFF7B1FA2); // Using the primary color from the widget
    
    if (clientPhone.isEmpty) {
      // If phone is not available, try to get it from client details
      final String clientId = requestData['clientId'] ?? '';
      if (clientId.isNotEmpty) {
        try {
          // Try to fetch client details to get the phone number
          final NotificationService notificationService = NotificationService();
          final clientDetails = await notificationService.getClientDetails(clientId);
            // Check if we have a valid phone number in the client details
          if (clientDetails.containsKey('phone') && clientDetails['phone'] != null && clientDetails['phone'].toString().isNotEmpty) {
            // We found a phone number, now try to call it
            _makePhoneCallWithClipboardOption(context, clientDetails['phone'].toString(), primaryColor);
            return;
          } else {
            // Show dialog that phone is not available
            _showPhoneNotAvailableDialog(context, primaryColor);
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('حدث خطأ أثناء محاولة الحصول على رقم الهاتف: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        // Show dialog that phone is not available
        _showPhoneNotAvailableDialog(context, primaryColor);
      }
    } else {
      // We have a phone number directly in requestData
      _makePhoneCallWithClipboardOption(context, clientPhone, primaryColor);
    }
  }
  
  // Helper method to make phone call with clipboard option
  Future<void> _makePhoneCallWithClipboardOption(BuildContext context, String phoneNumber, Color primaryColor) async {
    try {
      // Format phone number properly, removing unwanted characters
      String formattedNumber = phoneNumber.trim();
      formattedNumber = formattedNumber.replaceAll(RegExp(r'[\s\-)(]+'), '');
      final url = 'tel:$formattedNumber';
      final uri = Uri.parse(url);

      // Show a snackbar to indicate calling attempt
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('جاري الاتصال بالرقم $formattedNumber'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      // If launching the call app failed, show clipboard dialog
      if (!launched && context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 12,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    primaryColor.withOpacity(0.9),
                    primaryColor.withOpacity(0.7),
                    Colors.white,
                  ],
                  stops: const [0.0, 0.3, 0.9],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.phone_missed_rounded,
                          size: 56,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'لا يمكن فتح تطبيق الهاتف',
                          style: TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  // Content
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text(
                          'هل تريد نسخ رقم الهاتف إلى الحافظة؟',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF333333),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        
                        // Phone number in card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: primaryColor.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.phone_outlined,
                                size: 24,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  formattedNumber,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'إلغاء',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 2,
                                ),
                                onPressed: () {
                                  // نسخ رقم الهاتف إلى الحافظة
                                  Clipboard.setData(ClipboardData(text: formattedNumber));
                                  Navigator.pop(context);
                                  
                                  // عرض إشعار بأن الرقم تم نسخه
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم نسخ رقم الهاتف إلى الحافظة'),
                                      backgroundColor: Colors.green,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.content_copy, size: 18),
                                label: const Text(
                                  'نسخ الرقم',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء محاولة الاتصال: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  // Show dialog when phone is not available
  void _showPhoneNotAvailableDialog(BuildContext context, Color primaryColor) {
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 12,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  primaryColor.withOpacity(0.9),
                  primaryColor.withOpacity(0.7),
                  Colors.white,
                ],
                stops: const [0.0, 0.3, 0.9],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.phone_disabled_rounded,
                        size: 56,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'رقم الهاتف غير متوفر',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                // Content
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'لا يمكن العثور على رقم هاتف لهذا العميل',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF333333),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // View details button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _viewClientDetails(context);
                        },
                        icon: const Icon(Icons.account_circle_rounded),
                        label: const Text('عرض بيانات العميل'),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Cancel button
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('إغلاق'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  // Show request details
  void _showRequestDetails(BuildContext context, Color primaryColor, Color darkerPrimaryShade) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Extract necessary data within the builder scope
        final String detailVehicleType = requestData['vehicleType'] ?? '';
        final double detailPrice = (requestData['price'] ?? 0).toDouble();
        final String detailServiceName = requestData['serviceName'] ?? 'خدمة نقل';
        final String detailClientName = requestData['clientName'] ?? 'عميل';
        final String detailClientPhone = requestData['clientPhone'] ?? '';
        final String detailOriginName = requestData['originName'] ?? '';
        final String detailDestinationName = requestData['destinationName'] ?? '';
        final String detailDistanceText = requestData['distanceText'] ?? '';
        final String detailDurationText = requestData['durationText'] ?? '';
        final String detailRequestDetails = requestData['details'] ?? '';

        return Container(
          height: MediaQuery.of(context).size.height * 0.85, // Increased height
          padding: const EdgeInsets.only(top: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with close button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           Text(
                            'تفاصيل الطلب',
                            style: TextStyle(
                              fontSize: 24, // Increased size
                              fontWeight: FontWeight.bold,
                              color: darkerPrimaryShade, // Updated color
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: Colors.grey.shade600, size: 28), // Updated icon
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const Divider(height: 24, thickness: 0.8),
                      
                      // Price section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryColor, darkerPrimaryShade], // Updated gradient
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.4), // Updated shadow
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              'السعر الإجمالي للخدمة',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9), // Updated text color
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  ServiceVehiclesHelper.formatPrice(detailPrice).split(' ')[0],
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 36, // Increased size
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'دج',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 18, // Increased size
                                  ),
                                ),
                              ],
                            ),
                            if (detailVehicleType.isNotEmpty || detailDistanceText.isNotEmpty) 
                              Padding(
                                padding: const EdgeInsets.only(top: 15),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15), // Updated background
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (detailVehicleType.isNotEmpty)
                                        Row(
                                          children: [
                                            Icon(Icons.directions_car_rounded, color: Colors.white.withOpacity(0.85), size: 14), // Updated color
                                            const SizedBox(width: 8),
                                            Text(
                                              'نوع المركبة: $detailVehicleType',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.85), // Updated color
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      if (detailVehicleType.isNotEmpty && detailDistanceText.isNotEmpty) const SizedBox(height: 6),
                                      if (detailDistanceText.isNotEmpty)
                                        Row(
                                          children: [
                                            Icon(Icons.linear_scale_rounded, color: Colors.white.withOpacity(0.85), size: 14), // Updated color
                                            const SizedBox(width: 8),
                                            Text(
                                              'المسافة: $detailDistanceText',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.85), // Updated color
                                                fontSize: 13,
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
                      _buildDetailItem('اسم الخدمة:', detailServiceName, icon: Icons.info_outline_rounded, primaryColor: primaryColor, darkerPrimaryShade: darkerPrimaryShade),
                      _buildDetailItem('نوع الخدمة:', 'نقل', icon: Icons.category_rounded, primaryColor: primaryColor, darkerPrimaryShade: darkerPrimaryShade),
                      _buildDetailItem('اسم العميل:', detailClientName, icon: Icons.person_rounded, primaryColor: primaryColor, darkerPrimaryShade: darkerPrimaryShade),
                      _buildDetailItem('هاتف العميل:', detailClientPhone, icon: Icons.phone_rounded, isPhoneNumber: true, primaryColor: primaryColor, darkerPrimaryShade: darkerPrimaryShade),
                      
                      // Trip details section
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 16),
                        child: Text(
                          'تفاصيل الرحلة',
                          style: TextStyle(
                            fontSize: 20, // Increased size
                            fontWeight: FontWeight.bold,
                            color: darkerPrimaryShade, // Updated color
                          ),
                        ),
                      ),
                      
                      // Origin and destination details
                      _buildLocationItem(
                        'نقطة الانطلاق:',
                        detailOriginName,
                        Icons.my_location_rounded,
                        Colors.green.shade600,
                        darkerPrimaryShade: darkerPrimaryShade,
                      ),
                      _buildLocationItem(
                        'نقطة الوصول:',
                        detailDestinationName,
                        Icons.location_on_rounded,
                        Colors.red.shade600,
                        darkerPrimaryShade: darkerPrimaryShade,
                      ),
                      _buildDetailItem('المسافة:', detailDistanceText, icon: Icons.linear_scale_rounded, primaryColor: primaryColor, darkerPrimaryShade: darkerPrimaryShade),
                      _buildDetailItem('الوقت التقريبي:', detailDurationText, icon: Icons.timer_rounded, primaryColor: primaryColor, darkerPrimaryShade: darkerPrimaryShade),
                      _buildDetailItem('نوع المركبة:', detailVehicleType, icon: Icons.directions_car_filled_rounded, primaryColor: primaryColor, darkerPrimaryShade: darkerPrimaryShade),

                      // Request description
                      if (detailRequestDetails.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 8),
                          child: Text(
                            'وصف الطلب',
                            style: TextStyle(
                              fontSize: 18, // Increased size
                              fontWeight: FontWeight.bold,
                              color: darkerPrimaryShade, // Updated color
                            ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.05), // Updated background
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            detailRequestDetails,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade900, // Darker text
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 28), // Increased spacing
                      
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
              ),
            ],
          ),
        );
      },
    );
  }

  // Build detail item helper
  Widget _buildDetailItem(String label, String value, {IconData? icon, bool isPhoneNumber = false, required Color primaryColor, required Color darkerPrimaryShade}) {
    if (value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: primaryColor), // Updated icon color
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600, // Kept for contrast
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: isPhoneNumber ? Colors.blueAccent.shade700 : darkerPrimaryShade.withOpacity(0.85), // Updated value color
                    fontWeight: isPhoneNumber ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build location item helper
  Widget _buildLocationItem(String label, String value, IconData icon, Color color, {required Color darkerPrimaryShade}) {
    if (value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(left: 4, right: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15), // Adjusted opacity
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18,
              color: color,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600, // Kept for contrast
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: darkerPrimaryShade.withOpacity(0.85), // Updated value color
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
  // Complete request
  Future<void> _completeRequest(BuildContext context) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      
      final notificationService = NotificationService();
      final fcmService = FcmService();
      final String requestId = requestData['id'];
      final String clientId = requestData['clientId'] ?? '';
      final String providerId = FirebaseAuth.instance.currentUser?.uid ?? '';
      
      if (requestId.isEmpty || clientId.isEmpty || providerId.isEmpty) {
        if (context.mounted) Navigator.of(context).pop(); // Close loading dialog
        _showErrorSnackBar(context, 'بيانات الطلب غير مكتملة');
        return;
      }
      
      // Update request status in Firestore
      await notificationService.updateRequestStatus(
        requestId: requestId,
        status: 'completed',
      );
      
      // Send push notification to client
      await fcmService.sendNotificationToUser(
        userId: clientId,
        title: 'تم إكمال طلبك',
        body: 'تم إكمال طلب النقل الخاص بك من قبل مزود الخدمة',
        data: {
          'type': 'request_completed',
          'requestId': requestId,
          'providerId': providerId,
        },
      );
      
      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();
      
      // Update UI
      if (onRequestUpdated != null) {
        onRequestUpdated!();
      }
      
      _showSuccessSnackBar(context, 'تم إكمال الطلب بنجاح');
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop(); // Close loading dialog
      _showErrorSnackBar(context, 'حدث خطأ أثناء إكمال الطلب');
    }
  }
  // Delete request
  Future<void> _deleteRequest(BuildContext context) async {
    // Show confirmation dialog
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
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final String requestId = requestData['id'];
      if (requestId.isEmpty) {
        if (context.mounted) Navigator.of(context).pop(); // Close loading dialog
        _showErrorSnackBar(context, 'خطأ: لا يمكن حذف الطلب، معرف الطلب غير موجود');
        return;
      }

      // Check if request exists
      DocumentSnapshot? docSnapshot;
      docSnapshot = await FirebaseFirestore.instance.collection('serviceRequests').doc(requestId).get();
      if (!docSnapshot.exists) {
        docSnapshot = await FirebaseFirestore.instance.collection('service_requests').doc(requestId).get();
      }
      
      if (!docSnapshot.exists) {
        if (context.mounted) Navigator.of(context).pop(); // Close loading dialog
        _showErrorSnackBar(context, 'خطأ: الطلب غير موجود أو تم حذفه مسبقاً');
        return;
      }
      
      // Delete request from database
      String collectionName = docSnapshot.reference.parent.id;
      await FirebaseFirestore.instance.collection(collectionName).doc(requestId).delete();

      // Close loading dialog and show success message
      if (context.mounted) {
        Navigator.of(context).pop();
        _showSuccessSnackBar(context, 'تم حذف الطلب بنجاح');
        
        // Notify parent to update list
        if (onRequestUpdated != null) {
          onRequestUpdated!();
        }
      }
      
    } catch (error) {
      print('Error deleting request: $error');
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _showErrorSnackBar(context, 'حدث خطأ أثناء حذف الطلب');
      }
    }
  }
  // Show error snackbar
  void _showErrorSnackBar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  // Show success snackbar
  void _showSuccessSnackBar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// Custom painter for dashed line
class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({this.color = const Color(0xFF9CA3AF)}); // Default color updated in usage

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color // Use provided color
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

// Animation controller for card hover effect
class TransportCardAnimationController {
  final AnimationController controller;
  final Animation<double> scaleAnimation;
  final Animation<double> shadowAnimation;

  TransportCardAnimationController({required this.controller}) :
    scaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut)
    ),
    shadowAnimation = Tween<double>(begin: 2.0, end: 15.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut)
    );

  void dispose() {
    controller.dispose();
  }
}

// Enhanced path painter for route visualization
// Class removed to fix unused code error

// Animated shimmer effect for loading states
class ShimmerPainter extends CustomPainter {
  final double progress;
  final Color color;
  
  ShimmerPainter({required this.progress, this.color = Colors.white});
  
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      colors: [
        color.withOpacity(0.0),
        color.withOpacity(0.5),
        color.withOpacity(0.0),
      ],
      stops: const [0.0, 0.5, 1.0],
      begin: Alignment(progress - 1.5, 0.0),
      end: Alignment(progress, 0.0),
    );
    
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }
  
  @override
  bool shouldRepaint(covariant ShimmerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}