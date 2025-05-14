import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:bilink/screens/vehicle_type_selection_screen.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bilink/services/places_api_service.dart';
import 'package:bilink/services/directions_service.dart'; // إضافة استيراد خدمة الاتجاهات
import 'dart:async';

class TransportServiceMapUnified extends StatefulWidget {
  final LatLng? originLocation;
  final String? originName;
  final LatLng? destinationLocation;
  final String? destinationName;
  final Map<String, dynamic>? serviceData;
  
  const TransportServiceMapUnified({
    super.key, 
    this.originLocation,
    this.originName,
    this.destinationLocation,
    this.destinationName,
    this.serviceData,
  });

  @override
  State<TransportServiceMapUnified> createState() => _TransportServiceMapUnifiedState();
}

class _TransportServiceMapUnifiedState extends State<TransportServiceMapUnified> {
  bool _isLoading = true;
  bool _isSearchingOrigin = false;
  bool _isSearchingDestination = false;
  bool _showSearchResults = false;
  
  // Controllers for the map and search
  final Completer<GoogleMapController> _mapController = Completer();
  final TextEditingController _originSearchController = TextEditingController();
  final TextEditingController _destinationSearchController = TextEditingController();
  final FocusNode _originFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();
  
  // Location data
  LatLng? _originPosition;
  String _originAddress = '';
  LatLng? _destinationPosition;
  String _destinationAddress = '';
  
  // Search results
  List<Map<String, dynamic>> _originSearchResults = [];
  List<Map<String, dynamic>> _destinationSearchResults = [];
  Timer? _originDebounce;
  Timer? _destinationDebounce;
  
  // Places API
  late PlacesApiService _placesApiService;
  
  // Map configuration
  MapType _mapType = MapType.normal;
  final Color _primaryColor = const Color(0xFF0B3D91);
  final Color _accentColor = const Color(0xFF00A651); 
  final Color _secondaryColor = const Color(0xFFFF5722);
    // Directions & Route
  final DirectionsService _directionsService = DirectionsService();
  DirectionsResult? _directionsResult;
  List<LatLng> _polylineCoordinates = [];
  bool _isLoadingDirections = false;
  
  // Selection mode
  bool _isOriginSelectionMode = true;@override
  void initState() {
    super.initState();
    
    _placesApiService = PlacesApiService(apiKey: 'AIzaSyCSsMQzPwR92-RwufaNA9kPpi0nB4XjAtw');
    
    // Initialize controllers with any provided addresses
    if (widget.originName != null && widget.originName!.isNotEmpty) {
      _originSearchController.text = widget.originName!;
      _originAddress = widget.originName!;
    }
    
    if (widget.destinationName != null && widget.destinationName!.isNotEmpty) {
      _destinationSearchController.text = widget.destinationName!;
      _destinationAddress = widget.destinationName!;
    }
    
    // Initialize locations from widget if provided
    if (widget.originLocation != null) {
      _originPosition = widget.originLocation;
      setState(() {
        _isLoading = false;
      });
    }
    
    if (widget.destinationLocation != null) {
      _destinationPosition = widget.destinationLocation;
    }
    
    // Set up listeners for search input
    _originSearchController.addListener(_onOriginSearchChanged);
    _destinationSearchController.addListener(_onDestinationSearchChanged);
    
    // Set up focus listeners to show/hide search results
    _originFocusNode.addListener(() {
      if (mounted) {
        setState(() {
          _isOriginSelectionMode = _originFocusNode.hasFocus;
          if (_originFocusNode.hasFocus) {
            // عندما يحصل الحقل على التركيز، أظهر النتائج فقط إذا كان هناك نص وكانت هناك نتائج
            _showSearchResults = _originSearchController.text.isNotEmpty && _originSearchResults.isNotEmpty;
          } else {
            // عندما يفقد الحقل التركيز، أخفِ النتائج
            _showSearchResults = false;
          }
        });
      }
    });
    
    _destinationFocusNode.addListener(() {
      if (mounted) {
        setState(() {
          _isOriginSelectionMode = !_destinationFocusNode.hasFocus;
          if (_destinationFocusNode.hasFocus) {
            // عندما يحصل الحقل على التركيز، أظهر النتائج فقط إذا كان هناك نص وكانت هناك نتائج
            _showSearchResults = _destinationSearchController.text.isNotEmpty && _destinationSearchResults.isNotEmpty;
          } else {
            // عندما يفقد الحقل التركيز، أخفِ النتائج
            _showSearchResults = false;
          }
        });
      }
    });
    
    // If we don't have an origin yet, get current location
    if (_originPosition == null) {
      _getCurrentLocation();
    } else {
      // Move camera to origin position after a short delay to ensure map is ready
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted && _originPosition != null && _mapController.isCompleted) {
          _moveCamera(_originPosition!);
        }
      });
    }
  }
  
  @override
  void dispose() {
    _originSearchController.removeListener(_onOriginSearchChanged);
    _destinationSearchController.removeListener(_onDestinationSearchChanged);
    _originSearchController.dispose();
    _destinationSearchController.dispose();
    _originFocusNode.dispose();
    _destinationFocusNode.dispose();
    _originDebounce?.cancel();
    _destinationDebounce?.cancel();
    super.dispose();
  }
    void _onOriginSearchChanged() {
    if (_originDebounce?.isActive ?? false) _originDebounce!.cancel();
    
    // فقط أظهر نتائج البحث عندما يكون الحقل نشطًا وفيه نص
    setState(() {
      _showSearchResults = _originFocusNode.hasFocus && _originSearchController.text.isNotEmpty;
    });
    
    _originDebounce = Timer(const Duration(milliseconds: 500), () {
      if (_originSearchController.text.isNotEmpty) {
        _searchPlaces(_originSearchController.text, true);
      } else {
        setState(() {
          _originSearchResults = [];
          _isSearchingOrigin = false;
          _showSearchResults = false;
        });
      }
    });
  }
  
  void _onDestinationSearchChanged() {
    if (_destinationDebounce?.isActive ?? false) _destinationDebounce!.cancel();
    
    // فقط أظهر نتائج البحث عندما يكون الحقل نشطًا وفيه نص
    setState(() {
      _showSearchResults = _destinationFocusNode.hasFocus && _destinationSearchController.text.isNotEmpty;
    });
    
    _destinationDebounce = Timer(const Duration(milliseconds: 500), () {
      if (_destinationSearchController.text.isNotEmpty) {
        _searchPlaces(_destinationSearchController.text, false);
      } else {
        setState(() {
          _destinationSearchResults = [];
          _isSearchingDestination = false;
          _showSearchResults = false;
        });
      }
    });
  }Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (!mounted) return;
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted) return;
        
        if (permission == LocationPermission.denied) {
          _showError('لم يتم السماح باستخدام خدمة الموقع');
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        _showError('تم حظر استخدام خدمة الموقع. يرجى تفعيلها من إعدادات الجهاز');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      
      setState(() {
        _originPosition = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
      
      // Get address for the current location
      _getAddressFromLatLng(_originPosition!, true);
      
      // Add a small delay before moving the camera to ensure map is initialized
      Future.delayed(Duration(milliseconds: 300), () {
        if (mounted && _originPosition != null && _mapController.isCompleted) {
          _moveCamera(_originPosition!);
        }
      });
    } catch (e) {
      print('Error getting current location: $e');
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      // Use default position if we can't get current location
      if (_originPosition == null) {
        setState(() {
          _originPosition = const LatLng(36.7538, 3.0588); // Algeria default
        });
        Future.delayed(Duration(milliseconds: 300), () {
          if (mounted && _originPosition != null && _mapController.isCompleted) {
            _moveCamera(_originPosition!);
          }
        });
      }
      
      _showError('حدث خطأ أثناء تحديد موقعك الحالي');
    }
  }  Future<void> _getAddressFromLatLng(LatLng position, bool isOrigin) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

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
          if (isOrigin) {
            _originAddress = address;
            _originSearchController.text = address;
          } else {
            _destinationAddress = address;
            _destinationSearchController.text = address;
          }
        });
      }
    } catch (e) {
      print('Error getting address: $e');
    }
  }  void _searchPlaces(String query, bool isOrigin) async {
    if (!mounted) return;
    
    setState(() {
      if (isOrigin) {
        _isSearchingOrigin = true;
      } else {
        _isSearchingDestination = true;
      }
    });

    try {
      final predictions = await _placesApiService.getPlacePredictions(query);
      
      if (!mounted) return;
      
      setState(() {
        if (isOrigin) {
          _originSearchResults = predictions;
          _isSearchingOrigin = false;
          // فقط أظهر النتائج إذا كان حقل البحث نشطًا وهناك نتائج
          _showSearchResults = _originFocusNode.hasFocus && predictions.isNotEmpty;
        } else {
          _destinationSearchResults = predictions;
          _isSearchingDestination = false;
          // فقط أظهر النتائج إذا كان حقل البحث نشطًا وهناك نتائج
          _showSearchResults = _destinationFocusNode.hasFocus && predictions.isNotEmpty;
        }
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        if (isOrigin) {
          _originSearchResults = [];
          _isSearchingOrigin = false;
        } else {
          _destinationSearchResults = [];
          _isSearchingDestination = false;
        }
        _showSearchResults = false;
      });
      print('Error searching places: $e');
    }
  }  // بمجرد تحديد كل من نقطة البداية والوجهة، نحصل على مسار الطريق
  Future<void> _getDirections() async {
    // إذا لم تكن نقطتا البداية والوجهة محددتين، فلا يمكن الحصول على المسار
    if (_originPosition == null || _destinationPosition == null) return;
    
    setState(() {
      _isLoadingDirections = true;
    });

    try {
      final result = await _directionsService.getDirections(
        origin: _originPosition!,
        destination: _destinationPosition!,
      );

      if (mounted) {
        setState(() {
          _directionsResult = result;
          _polylineCoordinates = result?.polylinePoints ?? [];
          _isLoadingDirections = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDirections = false;
        });
        print('Error getting directions: $e');
      }
    }
  }

  Future<void> _selectSearchResult(Map<String, dynamic> place, bool isOrigin) async {
    final placeId = place['place_id'];
    
    setState(() {
      _isLoading = true;
      if (isOrigin) {
        _originSearchResults = [];
        _originSearchController.text = place['description'];
      } else {
        _destinationSearchResults = [];
        _destinationSearchController.text = place['description'];
      }
      // تأكد من إخفاء نتائج البحث عند اختيار نتيجة
      _showSearchResults = false;
    });

    try {
      final placeDetails = await _placesApiService.getPlaceDetails(placeId);
      if (!mounted) return;
      
      if (placeDetails != null && 
          placeDetails['geometry'] != null && 
          placeDetails['geometry']['location'] != null) {
        
        final locationData = placeDetails['geometry']['location'] as Map<String, dynamic>;
        final lat = locationData['lat'] as double;
        final lng = locationData['lng'] as double;
        final newPosition = LatLng(lat, lng);
      
        setState(() {
          if (isOrigin) {
            _originPosition = newPosition;
            _originAddress = place['description'];
          } else {
            _destinationPosition = newPosition;
            _destinationAddress = place['description'];
          }
          _isLoading = false;
        });
      
        // أزل التركيز من حقول الإدخال عند اختيار نتيجة
        FocusScope.of(context).unfocus();
        
        // تحريك الخريطة إلى الموقع المختار
        Future.delayed(Duration(milliseconds: 100), () {
          if (mounted && _mapController.isCompleted) {
            _moveCamera(newPosition);
          }
        });
        
        // الحصول على مسار الطريق إذا تم تحديد كل من نقطة البداية والوجهة
        if (_originPosition != null && _destinationPosition != null) {
          _getDirections();
        }
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        throw Exception('Invalid place details format');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      print('Error getting place details: $e');
      _showError('حدث خطأ أثناء تحديد الموقع');
    }
  }Future<void> _moveCamera(LatLng position) async {
    try {
      if (_mapController.isCompleted) {
        final controller = await _mapController.future;
        if (mounted) {
          controller.animateCamera(CameraUpdate.newCameraPosition(
            CameraPosition(
              target: position,
              zoom: 15,
            ),
          ));
        }
      }
    } catch (e) {
      print('Error moving camera: $e');
    }
  }  void _onMapTap(LatLng position) {
    if (!mounted) return;
    
    setState(() {
      if (_isOriginSelectionMode) {
        _originPosition = position;
      } else {
        _destinationPosition = position;
      }
      
      // إخفاء نتائج البحث دائمًا عند النقر على الخريطة
      _showSearchResults = false;
    });
    
    // Get address after updating position
    _getAddressFromLatLng(position, _isOriginSelectionMode);
    
    // Remove focus from text fields
    FocusScope.of(context).unfocus();
  }
    void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(10),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _proceedToVehicleSelection() {
    if (_originPosition == null || _destinationPosition == null) {
      _showError('الرجاء تحديد نقطة الانطلاق والوجهة');
      return;
    }
    
    // إذا لم تكن هناك معلومات طريق متاحة، احصل عليها قبل الانتقال للشاشة التالية
    if (_directionsResult == null) {
      // عرض رسالة تحميل
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(width: 16),
              Text('جاري حساب المسافة...')
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
      
      // الحصول على معلومات المسار
      _getDirections().then((_) {
        if (mounted) {
          _navigateToVehicleSelection();
        }
      });
    } else {
      _navigateToVehicleSelection();
    }
  }
  
  void _navigateToVehicleSelection() {
    if (!mounted) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VehicleTypeSelectionScreen(
          originLocation: _originPosition!,
          originName: _originAddress,
          destinationLocation: _destinationPosition!,
          destinationName: _destinationAddress,
          routeDistance: _directionsResult?.distanceInKm,
          routeDuration: _directionsResult?.durationInMinutes,
          distanceText: _directionsResult?.distanceText,
          durationText: _directionsResult?.durationText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                  ),
                )
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _originPosition ?? const LatLng(36.7538, 3.0588),
                    zoom: 14,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,                  mapType: _mapType,                  onMapCreated: (GoogleMapController controller) {
                    // تحقق مرة أخرى لتجنب استكمال المستقبل مرتين
                    if (!_mapController.isCompleted) {
                      try {
                        _mapController.complete(controller);
                      } catch (e) {
                        print('Error completing map controller: $e');
                      }
                      
                      // تحريك الكاميرا للموقع الحالي بعد تحميل الخريطة
                      if (_originPosition != null) {
                        Future.delayed(Duration(milliseconds: 300), () {
                          if (mounted) {
                            _moveCamera(_originPosition!);
                          }
                        });
                      }
                    }
                  },
                  onTap: _onMapTap,
                  markers: {
                    if (_originPosition != null)
                      Marker(
                        markerId: const MarkerId('origin'),
                        position: _originPosition!,
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                        infoWindow: InfoWindow(title: 'موقعك', snippet: _originAddress),
                      ),
                    if (_destinationPosition != null)
                      Marker(
                        markerId: const MarkerId('destination'),
                        position: _destinationPosition!,
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                        infoWindow: InfoWindow(title: 'الوجهة', snippet: _destinationAddress),
                      ),
                  },                  polylines: {
                    if (_originPosition != null && _destinationPosition != null)
                      Polyline(
                        polylineId: const PolylineId('route'),
                        points: _polylineCoordinates.isEmpty 
                            ? [_originPosition!, _destinationPosition!]  // Fallback to straight line
                            : _polylineCoordinates,  // Use real route from directions API
                        color: _secondaryColor,
                        width: 5,
                        patterns: [PatternItem.dash(10), PatternItem.gap(5)],  // Add pattern for better visibility
                      ),
                  },
                ),
          
          // Top controls
          SafeArea(
            child: Column(
              children: [
                // App bar with back button and map type toggle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          'اختيار الموقع والوجهة',
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
                
                // Search fields container - semi-transparent card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Origin search field
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.my_location,
                              color: _accentColor,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _originSearchController,
                                focusNode: _originFocusNode,
                                decoration: InputDecoration(
                                  hintText: 'حدد موقعك الحالي',
                                  hintStyle: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 14),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                  border: InputBorder.none,
                                  suffixIcon: _isSearchingOrigin
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: Padding(
                                            padding: const EdgeInsets.all(10.0),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: _accentColor,
                                            ),
                                          ),
                                        )
                                      : _originSearchController.text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                                              onPressed: () {
                                                setState(() {
                                                  _originSearchController.clear();
                                                  _originSearchResults = [];
                                                  _showSearchResults = false;
                                                });
                                              },
                                            )
                                          : null,
                                ),
                                textDirection: TextDirection.rtl,
                                textAlign: TextAlign.right,
                                style: GoogleFonts.cairo(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      Divider(height: 1, color: Colors.grey[300]),
                      
                      // Destination search field
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: _secondaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _destinationSearchController,
                                focusNode: _destinationFocusNode,
                                decoration: InputDecoration(
                                  hintText: 'حدد وجهتك',
                                  hintStyle: GoogleFonts.cairo(color: Colors.grey[600], fontSize: 14),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                  border: InputBorder.none,
                                  suffixIcon: _isSearchingDestination
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: Padding(
                                            padding: const EdgeInsets.all(10.0),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: _secondaryColor,
                                            ),
                                          ),
                                        )
                                      : _destinationSearchController.text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                                              onPressed: () {
                                                setState(() {
                                                  _destinationSearchController.clear();
                                                  _destinationSearchResults = [];
                                                  _showSearchResults = false;
                                                });
                                              },
                                            )
                                          : null,
                                ),
                                textDirection: TextDirection.rtl,
                                textAlign: TextAlign.right,
                                style: GoogleFonts.cairo(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Search results - displayed as a small popup instead of full screen
          if (_showSearchResults)
            Positioned(
              top: MediaQuery.of(context).padding.top + 120,
              left: 16,
              right: 16,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.3, // Limit to 30% of screen height
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Material(
                    color: Colors.transparent,
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _isOriginSelectionMode
                          ? _originSearchResults.length
                          : _destinationSearchResults.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        indent: 56,
                        endIndent: 16,
                        color: Colors.grey[300],
                      ),
                      itemBuilder: (context, index) {
                        final place = _isOriginSelectionMode
                            ? _originSearchResults[index]
                            : _destinationSearchResults[index];
                        return InkWell(
                          onTap: () => _selectSearchResult(place, _isOriginSelectionMode),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: _isOriginSelectionMode
                                      ? _accentColor.withOpacity(0.1)
                                      : _secondaryColor.withOpacity(0.1),
                                  child: Icon(
                                    Icons.location_on,
                                    color: _isOriginSelectionMode ? _accentColor : _secondaryColor,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        place['structured_formatting']['main_text'] ?? '',
                                        style: GoogleFonts.cairo(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        textDirection: TextDirection.rtl,
                                      ),
                                      if (place['structured_formatting']['secondary_text'] != null)
                                        Text(
                                          place['structured_formatting']['secondary_text'],
                                          style: GoogleFonts.cairo(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                          textDirection: TextDirection.rtl,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          
          // Floating guidance text when map is tapped
          if (_showSearchResults == false && (_originFocusNode.hasFocus || _destinationFocusNode.hasFocus))
            Positioned(
              top: MediaQuery.of(context).padding.top + 120,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    _isOriginSelectionMode ? 'اضغط على الخريطة لتحديد موقعك' : 'اضغط على الخريطة لتحديد وجهتك',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          
          // Bottom confirm button
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Route info card (shown only when both locations are selected and directions are loaded)
                  if (_originPosition != null && _destinationPosition != null && _directionsResult != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
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
                                  Icon(Icons.route, color: _secondaryColor, size: 22),
                                  const SizedBox(width: 8),
                                  Text(
                                    'المسافة: ${_directionsResult!.distanceText}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _secondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(Icons.access_time, color: _accentColor, size: 22),
                                  const SizedBox(width: 8),
                                  Text(
                                    'الوقت: ${_directionsResult!.durationText}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _accentColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  // Main action button
                  ElevatedButton(
                    onPressed: _originPosition != null && _destinationPosition != null
                        ? _proceedToVehicleSelection
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: Text(
                      'المتابعة للبحث عن مركبات',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // My location button
          Positioned(
            bottom: 90,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'myLocationBtn',
              onPressed: _getCurrentLocation,
              backgroundColor: Colors.white,
              elevation: 4,
              mini: true,
              child: Icon(
                Icons.my_location,
                color: _primaryColor,
              ),
            ),
          ),
          
          // Swap locations button
          if (_originPosition != null && _destinationPosition != null)
            Positioned(
              bottom: 90,
              left: 16,
              child: FloatingActionButton(
                heroTag: 'swapLocationsBtn',                onPressed: () {
                  setState(() {
                    // Swap positions
                    final tempPosition = _originPosition;
                    _originPosition = _destinationPosition;
                    _destinationPosition = tempPosition;
                    
                    // Swap addresses
                    final tempAddress = _originAddress;
                    _originAddress = _destinationAddress;
                    _destinationAddress = tempAddress;
                    
                    // Update controllers
                    _originSearchController.text = _originAddress;
                    _destinationSearchController.text = _destinationAddress;
                    
                    // Reset direction results - will be recalculated
                    _directionsResult = null;
                    _polylineCoordinates = [];
                  });
                  
                  // Calculate new route
                  _getDirections();
                },
                backgroundColor: Colors.white,
                elevation: 4,
                mini: true,
                child: Icon(
                  Icons.swap_vert,
                  color: _secondaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
