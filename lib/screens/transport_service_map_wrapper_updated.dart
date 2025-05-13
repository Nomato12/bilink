import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:bilink/screens/transport_service_map_updated_fixed.dart';
import 'package:bilink/screens/location_selection_screen_updated.dart';
import 'package:bilink/screens/vehicle_type_selection_screen.dart';

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
    
    // Initialize origin from widget parameters
    if (widget.originLocation != null) {
      _originPosition = widget.originLocation;
      _originAddress = widget.originName ?? '';
      print("TransportServiceMapWrapper: Origin location set from parameters");
    }
    
    // Initialize destination from widget parameters
    if (widget.destinationLocation != null) {
      _destinationPosition = widget.destinationLocation;
      _destinationAddress = widget.destinationName ?? '';
      print("TransportServiceMapWrapper: Destination location set from parameters");
    }
    
    // If we have both origin and destination, we can proceed directly
    if (_originPosition != null && _destinationPosition != null) {
      print("TransportServiceMapWrapper: Both origin and destination are available, ready to show map");
      setState(() {
        _isLoading = false;
      });
    } else {
      // Otherwise, start the location selection flow
      print("TransportServiceMapWrapper: Starting location selection flow");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startLocationSelectionFlow();
      });
    }
  }
  
  void _startLocationSelectionFlow() async {
    if (mounted) {
      // First select origin (current location)
      if (_originPosition == null) {
        final originResult = await _selectOriginLocation();
        if (!originResult && mounted) {
          // User cancelled origin selection, go back
          Navigator.pop(context);
          return;
        }
      }
      
      // Then select destination
      if (_originPosition != null && _destinationPosition == null && mounted) {
        final destinationResult = await _selectDestinationLocation();
        if (!destinationResult && mounted) {
          // User cancelled destination selection, go back
          Navigator.pop(context);
          return;
        }
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
                  backgroundColor: const Color(0xFF00A651), // Green accent color
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _originPosition == null ? 'تحديد موقعك الحالي' : 'تحديد وجهتك',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }
      // Show the map with both origin and destination
    return VehicleTypeSelectionScreen(
      originLocation: _originPosition!,
      originName: _originAddress,
      destinationLocation: _destinationPosition!,
      destinationName: _destinationAddress,
    );
  }
}
