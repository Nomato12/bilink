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
  final Color _accentColor = const Color(0xFF00A651); // Green for accent
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
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Map
          _selectedPosition == null
              ? Container(
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                )
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
                
          // Top panel with back button, search bar and map type toggle
          SafeArea(
            child: Column(
              children: [
                // Top bar with back button
                Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                  child: Row(
                    children: [
                      // Back button
                      Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(24),
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Icon(Icons.arrow_back, color: Colors.black),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Title
                      Expanded(
                        child: Text(
                          widget.isOriginSelection ? 'اختر موقعك الحالي' : 'اختر وجهتك',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.start,
                        ),
                      ),
                      
                      // Map type toggle
                      Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(24),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _mapType = _mapType == MapType.normal
                                  ? MapType.satellite
                                  : MapType.normal;
                            });
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Icon(
                              _mapType == MapType.normal ? Icons.map : Icons.map_outlined,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        decoration: InputDecoration(
                          hintText: 'ابحث عن موقع...',
                          hintStyle: GoogleFonts.cairo(color: Colors.grey[600]),
                          prefixIcon: _isSearching 
                              ? Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: _accentColor,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : Icon(Icons.search, color: _accentColor),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.grey),
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
                            vertical: 14,
                          ),
                        ),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        onChanged: (_) {}, // Handled by listener
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search results
          if (_searchResults.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 120, // Adjusted for search bar position
              left: 16,
              right: 16,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: Colors.grey[300],
                      indent: 56,
                      endIndent: 16,
                    ),
                    itemBuilder: (context, index) {
                      final place = _searchResults[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _accentColor.withOpacity(0.1),
                          child: Icon(
                            Icons.location_on,
                            color: _accentColor,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          place['structured_formatting']['main_text'] ?? '',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                        subtitle: Text(
                          place['structured_formatting']['secondary_text'] ?? '',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                        onTap: () => _selectSearchResult(place),
                        dense: true,
                      );
                    },
                  ),
                ),
              ),
            ),

          // Bottom sheet with location details and confirm button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Selected location info
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          widget.isOriginSelection ? Icons.my_location : Icons.location_on,
                          color: _accentColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isOriginSelection ? 'موقعك الحالي' : 'وجهتك',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              _selectedAddress.isNotEmpty ? _selectedAddress : 'يرجى تحديد موقع على الخريطة',
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Confirm button
                  ElevatedButton(
                    onPressed: _selectedPosition == null
                        ? null
                        : () {
                            Navigator.pop(context, {
                              'position': _selectedPosition,
                              'address': _selectedAddress,
                            });
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: Text(
                      'تأكيد الموقع',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Current location button (positioned beside the bottom sheet)
          Positioned(
            bottom: 150,
            right: 16,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(28),
              child: InkWell(
                onTap: _getCurrentLocation,
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Icon(
                    Icons.my_location,
                    color: _accentColor,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),

          // Loading indicator
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: CircularProgressIndicator(
                  color: _accentColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
