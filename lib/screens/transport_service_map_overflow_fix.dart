// This is a temporary fix for the transport service map screen 
// to resolve the RenderFlex overflow issue

// The fix needs to be applied to the ListView.builder inside the vehicle list section
// by wrapping the Column with a SingleChildScrollView and setting mainAxisSize: MainAxisSize.min

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bilink/screens/service_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:bilink/screens/fix_transport_map.dart' as map_fix;
import 'package:bilink/services/location_synchronizer.dart';
import 'package:bilink/services/directions_helper.dart';
import 'package:bilink/screens/directions_map_tracking.dart';

// To fix the overflow error in the ListView.builder of availableVehicles,
// the Container containing the vehicle card should be wrapped with SingleChildScrollView 
// and the Column should have mainAxisSize set to MainAxisSize.min

// Find in the file around line 590:
// Container(
//   width: 180,
//   margin: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
//   decoration: BoxDecoration(
//     color: Colors.white,
//     borderRadius: BorderRadius.circular(10),
//     boxShadow: [
//       BoxShadow(
//         color: Colors.black12,
//         blurRadius: 5,
//         offset: Offset(0, 2),
//       ),
//     ],
//   ),
//   child: Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: [
//       ...
//     ],
//   ),
// )

// Replace with:
// Container(
//   width: 180,
//   margin: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
//   decoration: BoxDecoration(
//     color: Colors.white,
//     borderRadius: BorderRadius.circular(10),
//     boxShadow: [
//       BoxShadow(
//         color: Colors.black12,
//         blurRadius: 5,
//         offset: Offset(0, 2),
//       ),
//     ],
//   ),
//   child: SingleChildScrollView(
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         ...
//       ],
//     ),
//   ),
// )
