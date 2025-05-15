// Improved lifecycle state error fix implementation
// This addresses the _ElementLifecycle.defunct assertion error in directions_map_tracking.dart
// and provides more comprehensive lifecycle handling for all async operations

import 'dart:async';
import 'package:flutter/material.dart';

class FixDirectionsMapLifecycle {
  // The specific implementations needed for the directions_map_tracking.dart file
  
  // 1. Add a proper dispose method that cancels all timers and subscriptions
  static String getDisposeImplementation() {
    return '''
  @override
  void dispose() {
    // Cancel any ongoing location tracking
    _stopTracking();
    
    // Cancel position stream subscription
    _positionStreamSubscription?.cancel();
    
    // Cancel any active timer
    _navigationUpdateTimer?.cancel();
    
    // Close any controllers if needed
    // _someController?.close();
    
    super.dispose();
  }
''';
  }
  
  // 2. Add mounted checks to all methods that update state asynchronously
  static String getStartTrackingImplementation() {
    return '''
  void _startTracking() async {
    // Request location permission if not already granted
    bool hasPermission = await _checkLocationPermission();
    if (!hasPermission) {
      // Show an error message
      if (!mounted) return; // Add mounted check before accessing context
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن بدء التتبع بدون صلاحية الوصول للموقع')),
      );
      return;
    }
    
    // Only proceed if the widget is still mounted
    if (!mounted) return;
    
    setState(() {
      _isTracking = true;
      _showDirectionsPanel = false;
    });
    
    // Start tracking logic...
  }
''';
  }
  
  // 3. Fix the stop tracking method to also include mounted check
  static String getStopTrackingImplementation() {
    return '''
  void _stopTracking() {
    // Cancel the navigation timer
    _navigationUpdateTimer?.cancel();
    _navigationUpdateTimer = null;
    
    // Cancel the position stream subscription
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    
    // Only update state if the widget is still mounted
    if (!mounted) return;
    
    setState(() {
      _isTracking = false;
      _currentNavigationPosition = null;
      _remainingTimeInSeconds = 0;
      _progressPercentage = 0.0;
    });
  }
''';
  }
  
  // 4. Update the position update callback with mounted check
  static String getPositionUpdateImplementation() {
    return '''
  void _onPositionUpdate(Position position) {
    // Create a new LatLng from the position
    final updatedPosition = LatLng(position.latitude, position.longitude);
    
    // Check if widget is still mounted before updating state
    if (!mounted) return;
    
    setState(() {
      _currentNavigationPosition = updatedPosition;
      
      // Update markers...
      _updateNavigationMarker(updatedPosition);
    });
    
    // Update camera position
    _animateToPosition(updatedPosition);
  }
''';
  }
}