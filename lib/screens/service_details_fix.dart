// This is a patch for the service details screen
// This file contains the corrected implementation for handling image URLs in service details
// Complete replacement for the part that crashes

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Function to safely parse and validate image URLs from service data
List<String> parseServiceImages(Map<String, dynamic> serviceData, String type) {
  List<String> validImageUrls = [];
  
  try {
    // Add main service images if available
    if (serviceData['imageUrls'] != null && serviceData['imageUrls'] is List) {
      List<dynamic> rawImages = List<dynamic>.from(serviceData['imageUrls']);
      for (var img in rawImages) {
        if (img != null && img.toString().isNotEmpty && 
            (img.toString().startsWith('http://') || img.toString().startsWith('https://'))) {
          validImageUrls.add(img.toString());
        }
      }
    }
    
    // Add vehicle images for transport services if available
    if (type == 'نقل' &&
        serviceData['vehicle'] != null &&
        serviceData['vehicle'] is Map) {
      if ((serviceData['vehicle'] as Map).containsKey('imageUrls')) {
        final vehicleImgs = serviceData['vehicle']['imageUrls'];
        if (vehicleImgs is List && vehicleImgs.isNotEmpty) {
          for (var img in vehicleImgs) {
            if (img != null && img.toString().isNotEmpty && 
                (img.toString().startsWith('http://') || img.toString().startsWith('https://')) &&
                !validImageUrls.contains(img.toString())) {
              validImageUrls.add(img.toString());
            }
          }
        }
      }
    }
    
    // Add storage location images for storage services if available
    if (type == 'تخزين' && serviceData['storageLocationImageUrls'] != null) {
      final locationImgs = serviceData['storageLocationImageUrls'];
      if (locationImgs is List && locationImgs.isNotEmpty) {
        for (var img in locationImgs) {
          if (img != null && img.toString().isNotEmpty && 
              (img.toString().startsWith('http://') || img.toString().startsWith('https://')) &&
              !validImageUrls.contains(img.toString())) {
            validImageUrls.add(img.toString());
          }
        }
      }
    }
  } catch (e) {
    print('Error processing service images: $e');
    // Return empty list in case of any error
  }
  
  return validImageUrls;
}

// A safer image carousel widget that handles invalid image URLs
class SafeImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final double height;
  final Function(int)? onPageChanged;
  
  const SafeImageCarousel({
    Key? key,
    required this.imageUrls,
    this.height = 350.0,
    this.onPageChanged,
  }) : super(key: key);
  
  @override
  _SafeImageCarouselState createState() => _SafeImageCarouselState();
}

class _SafeImageCarouselState extends State<SafeImageCarousel> {
  int _currentPage = 0;
  final PageController _pageController = PageController();
  
  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_not_supported, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'لا توجد صور متاحة',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }
    
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          // Images PageView
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              if (widget.onPageChanged != null) {
                widget.onPageChanged!(index);
              }
            },
            itemBuilder: (context, index) {
              final imageUrl = widget.imageUrls[index];
              return CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey[300],
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF8B5CF6),
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) {
                  print('Error loading image: $url - $error');
                  return Container(
                    color: Colors.grey[300],
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 40,
                            color: Colors.red[300],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'خطأ في تحميل الصورة',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          
          // Page indicators
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.imageUrls.length,
                  (index) => Container(
                    width: 8,
                    height: 8,
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
