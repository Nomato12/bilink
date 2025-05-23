import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:bilink/screens/transport_service_map_updated.dart';
import 'package:bilink/screens/location_selection_screen.dart';

class TransportServiceMapWrapper extends StatefulWidget {
  final LatLng? originLocation;
  final String? originName;
  final LatLng? destinationLocation;
  final String? destinationName;
  final Map<String, dynamic>? serviceData;
  
  const TransportServiceMapWrapper({
    super.key, 
    this.originLocation,
    this.originName,
    this.destinationLocation,
    this.destinationName,
    this.serviceData,
  });

  @override
  State<TransportServiceMapWrapper> createState() => _TransportServiceMapWrapperState();
}

class _TransportServiceMapWrapperState extends State<TransportServiceMapWrapper> {
  bool _isLoading = true;
  LatLng? _originPosition;
  String _originAddress = '';
  LatLng? _destinationPosition;
  String _destinationAddress = '';

  @override
  void initState() {
    super.initState();
    
    // Debug logging
    if (widget.serviceData != null) {
      print("TransportServiceMapWrapper: Service data received with ID: ${widget.serviceData!['id']}");
      
      // Check if location exists and is valid
      if (widget.serviceData!.containsKey('location') && 
          widget.serviceData!['location'] != null &&
          widget.serviceData!['location'] is Map) {
        
        final locationData = widget.serviceData!['location'] as Map<String, dynamic>;
        print("TransportServiceMapWrapper: Location data available: $locationData");
      } else {
        print("TransportServiceMapWrapper: No valid location in service data");
      }
    }
    
    // If we already have destination from service data, use it
    if (widget.serviceData != null || widget.destinationLocation != null) {
      _initFromServiceData();
    } else {
      // Otherwise start the location selection flow
      _startLocationSelectionFlow();
    }
  }

  // Initialize from provided service data
  Future<void> _initFromServiceData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    // Set destination from service data or directly provided destination
    if (widget.serviceData != null && widget.serviceData!['location'] != null) {
      final locationData = widget.serviceData!['location'] as Map<String, dynamic>?;
      _destinationPosition = safeGetLatLng(locationData);
      
      if (locationData != null && locationData['address'] != null) {
        _destinationAddress = locationData['address'].toString();
      }
    } else if (widget.destinationLocation != null) {
      _destinationPosition = widget.destinationLocation;
      _destinationAddress = widget.destinationName ?? 'الوجهة';
    }

    // Still need to select origin (current location)
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      
      // Now prompt user to select their current location
      _selectOriginLocation();
    }
  }

  // Start full location selection flow
  void _startLocationSelectionFlow() async {
    if (mounted) {
      // First select origin (current location)
      await _selectOriginLocation();
      
      // Then select destination
      if (_originPosition != null && mounted) {
        await _selectDestinationLocation();
      }
      
      // If both locations are selected, show the map
      if (_originPosition != null && _destinationPosition != null && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Present user interface to select current location
  Future<bool> _selectOriginLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationSelectionScreen(
          isOriginSelection: true,
        ),
      ),
    );
    
    if (result != null && mounted) {
      setState(() {
        _originPosition = result['position'];
        _originAddress = result['address'];
      });
      return true;
    }
    return false;
  }

  // Present user interface to select destination
  Future<bool> _selectDestinationLocation() async {
    if (_destinationPosition != null) {
      // We already have a destination from service data
      return true;
    }
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationSelectionScreen(
          isOriginSelection: false,
        ),
      ),
    );
    
    if (result != null && mounted) {
      setState(() {
        _destinationPosition = result['position'];
        _destinationAddress = result['address'];
      });
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while getting locations
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('خدمة النقل'),
          backgroundColor: const Color(0xFF0B3D91),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    // If we're missing origin or destination, show appropriate error and buttons to select
    if (_originPosition == null || _destinationPosition == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('خدمة النقل'),
          backgroundColor: const Color(0xFF0B3D91),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                _originPosition == null 
                    ? 'يرجى تحديد موقعك الحالي'
                    : 'يرجى تحديد وجهتك',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (_originPosition == null) {
                    _selectOriginLocation();
                  } else {
                    _selectDestinationLocation();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5722),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text(
                  _originPosition == null 
                      ? 'تحديد موقعك الحالي'
                      : 'تحديد وجهتك',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // We have both origin and destination, show the map
    return TransportServiceMapScreen(
      originLocation: _originPosition,
      originName: _originAddress,
      destinationLocation: _destinationPosition,
      destinationName: _destinationAddress,
    );
  }
  
  // Extract LatLng from Firestore location data safely
  LatLng? safeGetLatLng(Map<String, dynamic>? locationData) {
    if (locationData == null) {
      return null;
    }
    
    try {
      if (locationData.containsKey('geopoint')) {
        final geopoint = locationData['geopoint'];
        if (geopoint != null) {
          return LatLng(geopoint.latitude, geopoint.longitude);
        }
      } else if (locationData.containsKey('latitude') && 
                locationData.containsKey('longitude')) {
        final lat = locationData['latitude'];
        final lng = locationData['longitude'];
        if (lat != null && lng != null) {
          return LatLng(lat, lng);
        }
      }
    } catch (e) {
      print("Error extracting LatLng: $e");
    }
    
    return null;
  }
}
