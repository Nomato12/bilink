import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bilink/services/places_api_service.dart';

class LocationSelectionScreen extends StatefulWidget {
  final bool isOriginSelection;
  final LatLng? initialPosition;
  final String? initialAddress;

  const LocationSelectionScreen({
    super.key,
    this.isOriginSelection = true,
    this.initialPosition,
    this.initialAddress,
  });

  @override
  _LocationSelectionScreenState createState() => _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  // Controllers
  final Completer<GoogleMapController> _mapController = Completer();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Map state
  LatLng? _selectedPosition;
  String _selectedAddress = '';
  bool _isLoading = true;
  bool _isSearching = false;
  
  // Places API service
  late PlacesApiService _placesApiService;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounce;

  // Map style
  MapType _mapType = MapType.normal;
  final Color _primaryColor = const Color(0xFF0B3D91);
  final Color _secondaryColor = const Color(0xFFFF5722);

  @override
  void initState() {
    super.initState();
    _placesApiService = PlacesApiService(apiKey: 'AIzaSyCSsMQzPwR92-RwufaNA9kPpi0nB4XjAtw');
    
    if (widget.initialPosition != null) {
      _selectedPosition = widget.initialPosition;
      _selectedAddress = widget.initialAddress ?? '';
    }
    
    _getCurrentLocation();
    
    // Initialize search controller if initial address is provided
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _searchController.text = widget.initialAddress!;
    }
    
    // Listen for search input changes
    _searchController.addListener(_onSearchChanged);
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }
  
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.isNotEmpty) {
        _searchPlaces(_searchController.text);
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('لم يتم السماح باستخدام خدمة الموقع');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError('تم حظر استخدام خدمة الموقع. يرجى تفعيلها من إعدادات الجهاز');
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          if (_selectedPosition == null) {
            _selectedPosition = LatLng(position.latitude, position.longitude);
            _getAddressFromLatLng(_selectedPosition!);
          }
          _isLoading = false;
        });

        _moveCamera(_selectedPosition!);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Use default position if we can't get current location
        if (_selectedPosition == null) {
          setState(() {
            _selectedPosition = const LatLng(36.7538, 3.0588); // Algeria
          });
          _moveCamera(_selectedPosition!);
        }
        
        _showError('حدث خطأ أثناء تحديد موقعك الحالي');
      }
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.country,
        ].where((element) => element != null && element.isNotEmpty).join(', ');

        setState(() {
          _selectedAddress = address;
          _searchController.text = address;
        });
      }
    } catch (e) {
      print('Error getting address: $e');
    }
  }

  Future<void> _searchPlaces(String query) async {
    setState(() {
      _isSearching = true;
    });

    try {
      final predictions = await _placesApiService.getPlacePredictions(query);
      
      setState(() {
        _searchResults = predictions;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      print('Error searching places: $e');
    }
  }

  Future<void> _selectSearchResult(Map<String, dynamic> place) async {
    final placeId = place['place_id'];
    
    setState(() {
      _isLoading = true;
      _searchResults = [];
      _searchController.text = place['description'];
    });

    try {
      final latLng = await _placesApiService.getPlaceLatLng(placeId);
      
      if (latLng != null) {
        setState(() {
          _selectedPosition = latLng;
          _selectedAddress = place['description'];
        });
        
        _moveCamera(latLng);
      } else {
        _showError('لم نتمكن من العثور على هذا الموقع');
      }
    } catch (e) {
      _showError('حدث خطأ أثناء محاولة العثور على الموقع');
      print('Error selecting place: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _moveCamera(LatLng position) async {
    if (_mapController.isCompleted) {
      final controller = await _mapController.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: position,
            zoom: 15,
          ),
        ),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _primaryColor,
        title: Text(
          widget.isOriginSelection ? 'اختر موقعك الحالي' : 'اختر وجهتك',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _mapType == MapType.normal ? Icons.map : Icons.map_outlined,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _mapType = _mapType == MapType.normal
                    ? MapType.satellite
                    : MapType.normal;
              });
            },
            tooltip: 'تغيير نوع الخريطة',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          _selectedPosition == null
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  mapType: _mapType,
                  initialCameraPosition: CameraPosition(
                    target: _selectedPosition!,
                    zoom: 15,
                  ),
                  onMapCreated: (controller) {
                    _mapController.complete(controller);
                  },
                  markers: {
                    Marker(
                      markerId: const MarkerId('selected_location'),
                      position: _selectedPosition!,
                      infoWindow: InfoWindow(
                        title: widget.isOriginSelection ? 'موقعك الحالي' : 'وجهتك',
                        snippet: _selectedAddress,
                      ),
                    ),
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  onTap: (position) {
                    setState(() {
                      _selectedPosition = position;
                      _getAddressFromLatLng(position);
                    });
                  },
                ),

          // Search bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'ابحث عن موقع...',
                  hintStyle: GoogleFonts.cairo(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchResults = [];
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                onChanged: (_) {}, // Handled by listener
              ),
            ),
          ),

          // Search results
          if (_searchResults.isNotEmpty)
            Positioned(
              top: 76,
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).size.height * 0.4,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _searchResults.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final place = _searchResults[index];
                    return ListTile(
                      leading: const Icon(Icons.location_on),
                      title: Text(
                        place['structured_formatting']['main_text'] ?? '',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                        textDirection: TextDirection.rtl,
                      ),
                      subtitle: Text(
                        place['structured_formatting']['secondary_text'] ?? '',
                        style: GoogleFonts.cairo(),
                        textDirection: TextDirection.rtl,
                      ),
                      onTap: () => _selectSearchResult(place),
                    );
                  },
                ),
              ),
            ),

          // Loading indicator
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),

          // Current location button
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () async {
                await _getCurrentLocation();
              },
              child: const Icon(Icons.my_location, color: Colors.black),
            ),
          ),

          // Confirm button
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: _selectedPosition == null
                  ? null
                  : () {
                      Navigator.pop(context, {
                        'position': _selectedPosition,
                        'address': _selectedAddress,
                      });
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _secondaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: Text(
                'تأكيد الموقع',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
