import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageLocationMapPage extends StatefulWidget {
  final String serviceId;
  final Function(double, double, String)? onLocationSelected;

  const StorageLocationMapPage({
    super.key,
    required this.serviceId,
    this.onLocationSelected,
  });

  @override
  _StorageLocationMapPageState createState() => _StorageLocationMapPageState();
}

class _StorageLocationMapPageState extends State<StorageLocationMapPage> {
  // متغيرات الخريطة
  GoogleMapController? _mapController;
  CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(36.7525, 3.0422), // الجزائر العاصمة كموقع مبدئي
    zoom: 12,
  );

  // متغيرات الموقع
  Position? _currentPosition;
  LatLng? _selectedLocation;
  String _selectedAddress = "العنوان غير محدد";
  bool _isLoading = true;
  final Set<Marker> _markers = {};

  // متغيرات الصور
  final List<File> _locationImages = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // الحصول على إذن الموقع والموقع الحالي
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // التحقق من تفعيل خدمة الموقع
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('الرجاء تفعيل خدمة الموقع للاستمرار'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // التحقق من إذن الوصول للموقع
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('لم يتم السماح بالوصول للموقع'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم رفض إذن الموقع بشكل دائم. الرجاء تغيير الإعدادات',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'فتح الإعدادات',
              textColor: Colors.white,
              onPressed: () async {
                await Geolocator.openAppSettings();
              },
            ),
          ),
        );
        return;
      }

      // الحصول على الموقع الحالي بدقة عالية
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      );

      setState(() {
        _currentPosition = position;
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _initialCameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 15,
        );
        _isLoading = false;
      });

      _updateMarkerAndAddress();

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(_initialCameraPosition),
        );
      }
    } catch (e) {
      print('Error getting current location: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء تحديد الموقع الحالي: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // تحديث العلامة على الخريطة والعنوان النصي
  Future<void> _updateMarkerAndAddress() async {
    if (_selectedLocation == null) return;

    // تحديث العلامة على الخريطة
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: MarkerId('selected_location'),
          position: _selectedLocation!,
          infoWindow: InfoWindow(title: 'الموقع المحدد'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    });

    // الحصول على العنوان النصي من الإحداثيات
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
        localeIdentifier: 'ar',
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = '';

        if (place.street != null && place.street!.isNotEmpty) {
          address += '${place.street}';
        }

        if (place.locality != null && place.locality!.isNotEmpty) {
          if (address.isNotEmpty) address += '، ';
          address += '${place.locality}';
        }

        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          if (address.isNotEmpty) address += '، ';
          address += '${place.administrativeArea}';
        }

        if (place.country != null && place.country!.isNotEmpty) {
          if (address.isNotEmpty) address += '، ';
          address += '${place.country}';
        }

        setState(() {
          _selectedAddress = address.isNotEmpty ? address : 'العنوان غير متوفر';
        });
      }
    } catch (e) {
      print('Error getting address: $e');
      setState(() {
        _selectedAddress = 'تعذر الحصول على العنوان';
      });
    }
  }

  // إضافة صور للموقع
  Future<void> _pickLocationImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        setState(() {
          _locationImages.addAll(
            images.map((xFile) => File(xFile.path)).toList(),
          );
        });
      }
    } catch (e) {
      print('Error picking location images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء اختيار الصور: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // حفظ الموقع المحدد في قاعدة البيانات
  Future<void> _saveLocation() async {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('الرجاء تحديد الموقع أولاً'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _isUploading = true;
      });

      // تحميل صور الموقع (إذا كانت موجودة)
      final List<String> locationImageUrls = [];

      if (_locationImages.isNotEmpty) {
        for (var imageFile in _locationImages) {
          try {
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final imageName =
                'location_${timestamp}_${locationImageUrls.length}.jpg';
            final storageRef = FirebaseStorage.instance.ref().child(
              'locations/${widget.serviceId}/$imageName',
            );

            final uploadTask = storageRef.putFile(
              imageFile,
              SettableMetadata(
                contentType: 'image/jpeg',
                customMetadata: {
                  'latitude': _selectedLocation!.latitude.toString(),
                  'longitude': _selectedLocation!.longitude.toString(),
                  'address': _selectedAddress,
                },
              ),
            );

            final TaskSnapshot snapshot = await uploadTask;
            final String imageUrl = await snapshot.ref.getDownloadURL();
            locationImageUrls.add(imageUrl);
          } catch (e) {
            print('Error uploading location image: $e');
            continue;
          }
        }
      }

      // حفظ بيانات الموقع في Firestore
      await FirebaseFirestore.instance
          .collection('service_locations')
          .doc(widget.serviceId)
          .set({
            'serviceId': widget.serviceId,
            'latitude': _selectedLocation!.latitude,
            'longitude': _selectedLocation!.longitude,
            'address': _selectedAddress,
            'imageUrls': locationImageUrls,
            'timestamp': FieldValue.serverTimestamp(),
            'geoPoint': GeoPoint(
              _selectedLocation!.latitude,
              _selectedLocation!.longitude,
            ),
          });

      // استدعاء دالة رد النداء إذا كانت موجودة
      if (widget.onLocationSelected != null) {
        widget.onLocationSelected!(
          _selectedLocation!.latitude,
          _selectedLocation!.longitude,
          _selectedAddress,
        );
      }

      setState(() {
        _isLoading = false;
        _isUploading = false;
      });

      // عرض رسالة نجاح وإغلاق الصفحة
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حفظ الموقع بنجاح'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop({
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'address': _selectedAddress,
      });
    } catch (e) {
      print('Error saving location: $e');
      setState(() {
        _isLoading = false;
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء حفظ الموقع: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تحديد موقع التخزين'),
        backgroundColor: Color(0xFF5DADE2),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'تحديث الموقع الحالي',
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          // خريطة جوجل
          _isLoading && _currentPosition == null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF5DADE2)),
                    SizedBox(height: 16),
                    Text(
                      'جاري تحديد موقعك الحالي...',
                      style: TextStyle(
                        color: Color(0xFF5DADE2),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
              : GoogleMap(
                initialCameraPosition: _initialCameraPosition,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: true,
                mapToolbarEnabled: true,
                compassEnabled: true,
                markers: _markers,
                onMapCreated: (controller) {
                  setState(() {
                    _mapController = controller;
                  });
                },
                onTap: (LatLng location) {
                  setState(() {
                    _selectedLocation = location;
                  });
                  _updateMarkerAndAddress();
                },
              ),

          // بطاقة معلومات الموقع المحدد
          if (_selectedLocation != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Card(
                margin: EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // عنوان وإحداثيات الموقع
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Color(0xFF5DADE2).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.location_on,
                              color: Color(0xFF5DADE2),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'الموقع المحدد:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _selectedAddress,
                                  style: TextStyle(fontSize: 14),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'الإحداثيات: ${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // زر إضافة صور للموقع
                      if (_locationImages.isEmpty)
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Color(0xFF5DADE2),
                              width: 1.5,
                            ),
                          ),
                          child: OutlinedButton.icon(
                            onPressed: _pickLocationImages,
                            icon: Icon(
                              Icons.add_a_photo,
                              color: Color(0xFF5DADE2),
                            ),
                            label: Text(
                              'إضافة صور للموقع',
                              style: TextStyle(
                                color: Color(0xFF5DADE2),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide.none,
                              backgroundColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              minimumSize: Size(double.infinity, 50),
                            ),
                          ),
                        ),

                      // عرض الصور المختارة للموقع
                      if (_locationImages.isNotEmpty) ...[
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'تم اختيار ${_locationImages.length} صورة',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  TextButton.icon(
                                    onPressed: _pickLocationImages,
                                    icon: Icon(
                                      Icons.add_photo_alternate,
                                      size: 16,
                                      color: Color(0xFF5DADE2),
                                    ),
                                    label: Text(
                                      'إضافة المزيد',
                                      style: TextStyle(
                                        color: Color(0xFF5DADE2),
                                        fontSize: 12,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              SizedBox(
                                height: 110,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _locationImages.length,
                                  itemBuilder: (context, index) {
                                    return Stack(
                                      children: [
                                        Container(
                                          margin: EdgeInsets.only(right: 8),
                                          width: 110,
                                          height: 110,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            image: DecorationImage(
                                              image: FileImage(
                                                _locationImages[index],
                                              ),
                                              fit: BoxFit.cover,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.1,
                                                ),
                                                blurRadius: 4,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Positioned(
                                          top: 5,
                                          right: 13,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _locationImages.removeAt(index);
                                              });
                                            },
                                            child: Container(
                                              padding: EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.2),
                                                    blurRadius: 4,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      SizedBox(height: 16),

                      // أزرار الإلغاء والتأكيد
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedLocation = null;
                                  _markers.clear();
                                  _locationImages.clear();
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey[700],
                                padding: EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(color: Colors.grey[400]!),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text('إلغاء التحديد'),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _saveLocation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF5DADE2),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child:
                                  _isUploading
                                      ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text('جاري الحفظ...'),
                                        ],
                                      )
                                      : Text('تأكيد الموقع'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // مؤشر التحميل
          if (_isLoading && !(_isLoading && _currentPosition == null))
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
