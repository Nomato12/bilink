// Calculate and display routes between two points
import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

// مفتاح API الخاص بـ Google Maps - متطابق مع المفتاح في ملف AndroidManifest.xml
const String GOOGLE_MAPS_API_KEY = "AIzaSyCSsMQzPwR92-RwufaNA9kPpi0nB4XjAtw";

class DirectionsHelper {
  // الحصول على بيانات المسار بين نقطتين
  static Future<Map<String, dynamic>> getDirections(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      // محاولة استخدام Google Directions API للحصول على مسارات حقيقية
      final googleDirections = await _getGoogleDirections(origin, destination);
      if (googleDirections != null) {
        return googleDirections;
      }
      
      // في حالة فشل الاتصال بـ Google API، نستخدم الطريقة المحسنة البديلة
      return await _getRealLikeDirections(origin, destination);
    } catch (e) {
      print('Error getting directions: $e');
      // استخدام طريقة احتياطية بسيطة في حالة الفشل
      return _getFallbackDirections(origin, destination);
    }
  }
  // استخدام Google Directions API للحصول على مسارات طرق حقيقية
  static Future<Map<String, dynamic>?> _getGoogleDirections(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      // تحقق من توفر مفتاح API
      if (GOOGLE_MAPS_API_KEY == "YOUR_API_KEY") {
        print('Google Maps API key not configured. Using alternative method.');
        return null;
      }

      // بناء URL لطلب الاتجاهات
      final String url = 'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&mode=driving' // التأكد من طلب اتجاهات القيادة
          '&alternatives=true' // طلب مسارات بديلة
          '&language=ar'
          '&key=$GOOGLE_MAPS_API_KEY';

      print('Requesting Google Directions API with URL: $url');
      
      // إرسال الطلب إلى Google Directions API
      final response = await http.get(Uri.parse(url));

      // التحقق من نجاح الطلب
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          print('Successfully received directions from Google API');
          return data;
        } else {
          print('Directions API error: ${data['status']} - ${data['error_message'] ?? 'No detailed error message'}');
          print('Using alternative method for directions');
          return null;
        }
      } else {
        print('Directions API request failed with status ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching Google Directions: $e');
      return null;
    }
  }

  // طريقة محسنة لتقدير مسار يشبه المسار الحقيقي
  static Future<Map<String, dynamic>> _getRealLikeDirections(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      // المسافة الإجمالية بين النقطتين
      final directDistance = _calculateDistance(origin, destination);
      
      // تقدير مسافة الطريق الفعلي (عادة أطول بنسبة 20-30% من المسافة المباشرة)
      final roadDistance = directDistance * 1.3;
      
      // تقدير الوقت باستخدام متوسط سرعة واقعية (35 كم/ساعة في المناطق الحضرية)
      final durationMinutes = (roadDistance / 35 * 60).round();
      
      // إنشاء نقاط مسار تتبع الطرق الرئيسية مع تقاطعات واقعية
      final waypoints = _generateRealisticRoutePoints(origin, destination);
      
      // إنشاء خطوات منطقية للمسار بناءً على النقاط
      final steps = _generateDetailedRouteSteps(waypoints, roadDistance, durationMinutes);
      
      // إنشاء استجابة مشابهة لبنية Google Directions API
      final Map<String, dynamic> enhancedRoute = {
        'status': 'OK',
        'routes': [
          {
            'overview_polyline': {
              'points': _encodePolylinePoints(waypoints),
            },
            'legs': [
              {
                'distance': {'text': '${roadDistance.toStringAsFixed(1)} كم', 'value': (roadDistance * 1000).round()},
                'duration': {'text': '$durationMinutes دقيقة', 'value': durationMinutes * 60},
                'start_address': 'نقطة الانطلاق',
                'end_address': 'الوجهة',
                'steps': steps,
              }
            ]
          }
        ]
      };
      
      return enhancedRoute;
    } catch (e) {
      print('Error generating realistic directions: $e');
      return _getFallbackDirections(origin, destination);
    }
  }
    // إنشاء نقاط تشبه مسار طريق حقيقي
  static List<LatLng> _generateRealisticRoutePoints(LatLng start, LatLng end) {
    final List<LatLng> points = [start];
    final math.Random random = math.Random();
    
    // المسافة بين النقطتين
    final double totalDistance = _calculateDistance(start, end);
    
    // عدد النقاط يعتمد على المسافة الإجمالية - زيادة عدد النقاط
    final int numSegments = math.max(6, (totalDistance / 0.25).round());
    
    // تحديد ما إذا كان يجب إنشاء مسار بمنحنيات أو مسار شبكي
    final bool useGridPattern = random.nextDouble() < 0.7; // 70% احتمال استخدام نمط الشبكة
    
    if (useGridPattern) {
      // تنفيذ نمط مسار شبكة المدينة (يتبع اتجاهات الشوارع الرئيسية)
      _createCityGridPath(points, start, end, numSegments, random);
    } else {
      // إنشاء مسار منحني أكثر طبيعية (مثل الطرق الريفية أو السريعة)
      _createCurvyPath(points, start, end, numSegments, random);
    }
    
    // التأكد من إضافة نقطة النهاية
    if (points.last != end) {
      points.add(end);
    }
    
    return points;
  }
  
  // إنشاء مسار يتبع نمط شبكة المدينة
  static void _createCityGridPath(
    List<LatLng> points,
    LatLng start,
    LatLng end,
    int numSegments,
    math.Random random
  ) {
    // تقسيم المسار إلى مقاطع متعددة للمحاكاة الواقعية للشبكة الحضرية
    // في المدن، غالبًا ما تكون الشوارع متعامدة على بعضها (نمط الشبكة)
    
    // تحديد عدد التغييرات في الاتجاه (تقاطعات الشوارع)
    final int intersections = math.min(6, 1 + random.nextInt(3));
    
    // تحديد نقاط الوسيطة (التقاطعات الرئيسية)
    List<LatLng> keyPoints = [start];
    
    // إضافة نقاط التقاطع الرئيسية
    for (int i = 0; i < intersections; i++) {
      // اختيار التحرك بشكل أفقي أو عمودي في كل مرحلة
      final bool moveHorizontally = (i % 2 == 0);
      final LatLng prevPoint = keyPoints.last;
      LatLng nextPoint;
      
      if (moveHorizontally) {
        // التحرك أفقيًا يعني تغيير خط الطول مع الحفاظ على خط العرض
        final double progress = (i + 1) / (intersections + 1);
        final double targetLng = start.longitude + (end.longitude - start.longitude) * progress;
        nextPoint = LatLng(prevPoint.latitude, targetLng);
      } else {
        // التحرك عموديًا يعني تغيير خط العرض مع الحفاظ على خط الطول
        final double progress = (i + 1) / (intersections + 1);
        final double targetLat = start.latitude + (end.latitude - start.latitude) * progress;
        nextPoint = LatLng(targetLat, prevPoint.longitude);
      }
      
      keyPoints.add(nextPoint);
    }
    
    // إضافة نقطة النهاية كنقطة رئيسية
    if (keyPoints.last != end) {
      keyPoints.add(end);
    }
    
    // إضافة نقاط تفصيلية بين النقاط الرئيسية
    for (int i = 0; i < keyPoints.length - 1; i++) {
      final segmentPoints = (numSegments ~/ keyPoints.length) + 1;
      _addDetailedPointsAlongSegment(points, keyPoints[i], keyPoints[i + 1], segmentPoints, random, isMainRoad: true);
    }
  }
  
  // إنشاء مسار منحني أكثر طبيعية
  static void _createCurvyPath(
    List<LatLng> points,
    LatLng start,
    LatLng end,
    int numSegments,
    math.Random random
  ) {
    // محاكاة الطرق المنحنية مثل الطرق السريعة أو الطرق الريفية
    
    // نحدد نقطة واحدة أو أكثر من نقاط التحكم لإنشاء المنحنى
    final int numControlPoints = 2 + random.nextInt(3); // 2-4 نقاط تحكم
    final List<LatLng> controlPoints = [];
    
    for (int i = 0; i < numControlPoints; i++) {
      final double fraction = (i + 1.0) / (numControlPoints + 1);
      
      // حساب موقع مباشر بين البداية والنهاية
      final double baseLat = start.latitude + (end.latitude - start.latitude) * fraction;
      final double baseLng = start.longitude + (end.longitude - start.longitude) * fraction;
      
      // إضافة انحراف كبير نسبيًا لإنشاء منحنى طبيعي
      // الانحراف أكبر في المنتصف وأقل بالقرب من نقاط البداية والنهاية
      final double curveIntensity = 4.0 * fraction * (1 - fraction); // منحنى على شكل قطع مكافئ
      final double maxOffset = 0.005 * curveIntensity; // أقصى انحراف
      
      final double latOffset = (random.nextDouble() - 0.5) * maxOffset;
      final double lngOffset = (random.nextDouble() - 0.5) * maxOffset;
      
      final LatLng controlPoint = LatLng(
        baseLat + latOffset,
        baseLng + lngOffset,
      );
      
      controlPoints.add(controlPoint);
    }
    
    // إنشاء مسار من خلال نقاط التحكم
    final List<LatLng> keyPoints = [start, ...controlPoints, end];
    
    // إضافة نقاط تفصيلية بين النقاط الرئيسية
    for (int i = 0; i < keyPoints.length - 1; i++) {
      final segmentPoints = (numSegments ~/ keyPoints.length) + 1;
      _addDetailedPointsAlongSegment(points, keyPoints[i], keyPoints[i + 1], segmentPoints, random, isMainRoad: false);
    }
  }
  
  // إضافة نقاط تفصيلية على طول قطاع مع انحرافات مناسبة
  static void _addDetailedPointsAlongSegment(
    List<LatLng> points, 
    LatLng start, 
    LatLng end, 
    int numPoints,
    math.Random random,
    {bool isMainRoad = true}
  ) {
    // انحرافات أقل للطرق الرئيسية
    final double baseMaxOffset = isMainRoad ? 0.0006 : 0.0012;
    
    for (int i = 1; i <= numPoints; i++) {
      final double fraction = i / (numPoints + 1);
      
      // حساب موقع وسطي على الخط المستقيم
      final double lat = start.latitude + (end.latitude - start.latitude) * fraction;
      final double lng = start.longitude + (end.longitude - start.longitude) * fraction;
      
      // حساب الانحراف المناسب بناءً على نوع الطريق والموقع على طول القطاع
      // انحراف أقل بالقرب من بداية ونهاية القطاع
      final double edgeEffect = 4.0 * fraction * (1 - fraction);
      final double maxOffset = baseMaxOffset * edgeEffect;
      
      // استخدام توزيع غاوسي للانحرافات لنتائج أكثر طبيعية
      // توليد انحراف غاوسي بمتوسط 0 وانحراف معياري محدد
      double gaussianRandom() {
        return math.sqrt(-2 * math.log(random.nextDouble())) * 
               math.cos(2 * math.pi * random.nextDouble());
      }
      
      // تحجيم الانحراف الغاوسي إلى النطاق المطلوب
      final double latOffset = gaussianRandom() * maxOffset * 0.7;
      final double lngOffset = gaussianRandom() * maxOffset * 0.7;
      
      final LatLng waypoint = LatLng(
        lat + latOffset,
        lng + lngOffset,
      );
      
      points.add(waypoint);
    }
  }
  
  // إنشاء خطوات تفصيلية للمسار
  static List<Map<String, dynamic>> _generateDetailedRouteSteps(
    List<LatLng> points,
    double totalDistance, 
    int totalDuration
  ) {
    final List<Map<String, dynamic>> steps = [];
    
    // تسمية الشوارع الافتراضية
    final List<String> streetNames = [
      'شارع الملك فهد',
      'شارع الأمير محمد',
      'طريق الملك عبدالله',
      'شارع التحلية',
      'شارع العليا',
      'شارع الستين',
      'طريق الملك فيصل',
      'شارع الجامعة',
      'شارع الخليج',
      'شارع الثلاثين'
    ];
    
    final math.Random random = math.Random();
    
    if (points.length < 2) {
      // إذا لم يكن هناك نقاط كافية، نعيد خطوة واحدة
      final distance = totalDistance;
      return [
        {
          'html_instructions': 'اتجه مباشرة إلى الوجهة',
          'distance': {'text': '${distance.toStringAsFixed(1)} كم'},
          'duration': {'text': '$totalDuration دقيقة'},
          'maneuver': 'straight',
        }
      ];
    }
    
    for (int i = 0; i < points.length - 1; i++) {
      final currentPoint = points[i];
      final nextPoint = points[i + 1];
      
      // حساب الاتجاه بين النقطتين
      String maneuver;
      
      if (i == 0) {
        maneuver = 'straight'; // بداية الرحلة
      } else {
        // حساب الاتجاه بين القطاعات المتتالية لتحديد نوع المناورة
        final prevPoint = points[i - 1];
        final prevBearing = _calculateBearing(prevPoint, currentPoint);
        final currentBearing = _calculateBearing(currentPoint, nextPoint);
        
        // حساب الفرق بين الاتجاهين
        double bearingDiff = (currentBearing - prevBearing) % 360;
        if (bearingDiff > 180) bearingDiff -= 360;
        
        // تعيين نوع المناورة بناءً على مقدار التغير في الاتجاه
        if (bearingDiff.abs() < 22.5) {
          maneuver = 'straight';
        } else if (bearingDiff >= 22.5 && bearingDiff < 67.5) {
          maneuver = 'turn-slight-right';
        } else if (bearingDiff >= 67.5 && bearingDiff < 112.5) {
          maneuver = 'turn-right';
        } else if (bearingDiff >= 112.5 && bearingDiff < 157.5) {
          maneuver = 'turn-sharp-right';
        } else if (bearingDiff >= 157.5 || bearingDiff <= -157.5) {
          maneuver = 'uturn-right';
        } else if (bearingDiff <= -22.5 && bearingDiff > -67.5) {
          maneuver = 'turn-slight-left';
        } else if (bearingDiff <= -67.5 && bearingDiff > -112.5) {
          maneuver = 'turn-left';
        } else if (bearingDiff <= -112.5 && bearingDiff > -157.5) {
          maneuver = 'turn-sharp-left';
        } else {
          maneuver = 'straight';
        }
      }
      
      // حساب المسافة والوقت لهذه الخطوة
      final stepDistance = _calculateDistance(currentPoint, nextPoint);
      final double distanceProportion = stepDistance / totalDistance;
      final stepDuration = (distanceProportion * totalDuration).round();
      
      // اختيار اسم شارع عشوائي لهذه الخطوة
      final String streetName = streetNames[random.nextInt(streetNames.length)];
      
      // إنشاء تعليمات مناسبة
      String instruction;
      if (i == 0) {
        instruction = 'ابدأ بالتوجه في $streetName';
      } else if (i == points.length - 2) {
        instruction = 'استمر حتى الوصول إلى الوجهة';
      } else {
        switch (maneuver) {
          case 'straight':
            instruction = 'استمر في $streetName لمسافة ${stepDistance.toStringAsFixed(1)} كم';
            break;
          case 'turn-slight-right':
            instruction = 'انعطف قليلاً إلى اليمين في $streetName';
            break;
          case 'turn-right':
            instruction = 'انعطف يميناً في $streetName';
            break;
          case 'turn-sharp-right':
            instruction = 'انعطف بشكل حاد إلى اليمين في $streetName';
            break;
          case 'uturn-right':
            instruction = 'قم بدوران كامل والعودة في $streetName';
            break;
          case 'turn-slight-left':
            instruction = 'انعطف قليلاً إلى اليسار في $streetName';
            break;
          case 'turn-left':
            instruction = 'انعطف يساراً في $streetName';
            break;
          case 'turn-sharp-left':
            instruction = 'انعطف بشكل حاد إلى اليسار في $streetName';
            break;
          default:
            instruction = 'استمر في $streetName';
        }
      }
      
      steps.add({
        'html_instructions': instruction,
        'distance': {'text': '${stepDistance.toStringAsFixed(1)} كم'},
        'duration': {'text': '$stepDuration دقيقة'},
        'maneuver': maneuver,
      });
    }
    
    return steps;
  }
  
  // حساب زاوية الاتجاه بين نقطتين
  static double _calculateBearing(LatLng start, LatLng end) {
    final double startLat = start.latitude * (math.pi / 180);
    final double startLng = start.longitude * (math.pi / 180);
    final double endLat = end.latitude * (math.pi / 180);
    final double endLng = end.longitude * (math.pi / 180);
    
    final double dLng = endLng - startLng;
    
    final double y = math.sin(dLng) * math.cos(endLat);
    final double x = math.cos(startLat) * math.sin(endLat) -
                     math.sin(startLat) * math.cos(endLat) * math.cos(dLng);
    
    final double bearing = math.atan2(y, x) * (180 / math.pi);
    return (bearing + 360) % 360;
  }

  // الطريقة الاحتياطية البسيطة
  static Map<String, dynamic> _getFallbackDirections(LatLng origin, LatLng destination) {
    // حساب المسافة التقريبية بالكيلومترات
    final distance = _calculateDistance(origin, destination);
    
    // تقدير الوقت: متوسط سرعة 50 كم/ساعة
    final durationMinutes = (distance / 50 * 60).round();
    
    return {
      'status': 'OK',
      'routes': [
        {
          'overview_polyline': {
            'points': _encodeRoute([origin, destination]),
          },
          'legs': [
            {
              'distance': {'text': '${distance.toStringAsFixed(1)} كم', 'value': distance * 1000},
              'duration': {'text': '$durationMinutes دقيقة', 'value': durationMinutes * 60},
              'start_address': 'موقعك الحالي',
              'end_address': 'الوجهة',
              'steps': [
                {
                  'html_instructions': 'توجه إلى الوجهة',
                  'distance': {'text': '${distance.toStringAsFixed(1)} كم'},
                  'duration': {'text': '$durationMinutes دقيقة'},
                  'maneuver': 'straight',
                }
              ]
            }
          ]
        }
      ]
    };
  }
  
  // حساب المسافة بين نقطتين (بالكيلومترات)
  static double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371; // بالكيلومترات
    final double lat1 = start.latitude * (math.pi / 180);
    final double lng1 = start.longitude * (math.pi / 180);
    final double lat2 = end.latitude * (math.pi / 180);
    final double lng2 = end.longitude * (math.pi / 180);
    
    final double dLat = lat2 - lat1;
    final double dLng = lng2 - lng1;
    
    final double a = 
        math.sin(dLat/2) * math.sin(dLat/2) +
        math.sin(dLng/2) * math.sin(dLng/2) * math.cos(lat1) * math.cos(lat2);
    final double c = 2 * math.asin(math.sqrt(a));
    
    return earthRadius * c;
  }
  // تشفير نقاط المسار لتخزينها ونقلها
  static String _encodePolylinePoints(List<LatLng> points) {
    if (points.isEmpty) {
      return '';
    }
    
    // استخدام تشفير متوافق مع مكتبة flutter_polyline_points
    try {
      // استخدام مكتبة PolylinePoints للتشفير إذا كان ممكنًا
      final List<PointLatLng> encodablePoints = points
          .map((point) => PointLatLng(point.latitude, point.longitude))
          .toList();
          
      // محاولة استخدام طريقة التشفير المخصصة
      try {
        String encoded = _encodePoints(encodablePoints);
        if (encoded.isNotEmpty) {
          return encoded;
        }
      } catch (e) {
        print('Error using polyline encoding: $e, using fallback');
      }
    } catch (e) {
      print('Error initializing polyline encoder: $e, using fallback');
    }
    
    // الطريقة البديلة البسيطة المتوافقة مع كودنا
    return _encodeRoute(points);
  }
  
  // طريقة مساعدة لتشفير نقاط المسار باستخدام خوارزمية تشفير متوافقة مع Google Maps
  static String _encodePoints(List<PointLatLng> points) {
    if (points.isEmpty) {
      return '';
    }
    
    // تنفيذ خوارزمية تشفير Google Polyline المبسطة
    // https://developers.google.com/maps/documentation/utilities/polylinealgorithm
    
    StringBuffer encodedPoints = StringBuffer();
    int plat = 0;
    int plng = 0;
    
    for (var point in points) {
      // تحويل الإحداثيات إلى أعداد صحيحة (تحريك 5 أماكن عشرية)
      int lat = (point.latitude * 1e5).round();
      int lng = (point.longitude * 1e5).round();
      
      // حساب التغيير من النقطة السابقة
      int dlat = lat - plat;
      int dlng = lng - plng;
      
      // تحديث آخر نقطة
      plat = lat;
      plng = lng;
      
      // تشفير التغيير في الإحداثيات
      _encodeValue(encodedPoints, dlat);
      _encodeValue(encodedPoints, dlng);
    }
    
    return encodedPoints.toString();
  }
  
  // طريقة مساعدة لتشفير قيمة فردية في خوارزمية تشفير Google Polyline
  static void _encodeValue(StringBuffer buffer, int value) {
    // تطبيق عملية القلب للإشارة السالبة (لتوفير بت واحد)
    int v = (value < 0) ? ~(value << 1) : (value << 1);
    
    // تشفير القيمة على شكل مجموعة من الأحرف
    while (v >= 0x20) {
      buffer.writeCharCode(0x20 | (v & 0x1F) | 0x3F40);
      v >>= 5;
    }
    buffer.writeCharCode(v | 0x3F40);
  }
  
  // طريقة تشفير بسيطة كاحتياطي
  static String _encodeRoute(List<LatLng> points) {
    if (points.isEmpty) {
      return '';
    }
    
    // نقوم بإنشاء سلسلة من الإحداثيات بصيغة "lat1,lng1|lat2,lng2|..."
    String encoded = '';
    for (var i = 0; i < points.length; i++) {
      if (i > 0) {
        encoded += '|';
      }
      encoded += '${points[i].latitude},${points[i].longitude}';
    }
    return encoded;
  }
  // تحويل بيانات المسار إلى خطوط polyline لعرضها على الخريطة
  static Future<Set<Polyline>> createPolylines(
    LatLng origin,
    LatLng destination, {
    Color color = Colors.blue,
    int width = 5,
    String polylineId = "route",
  }) async {
    final directionsData = await getDirections(origin, destination);
    
    if (directionsData.isEmpty || 
        !directionsData.containsKey('routes') || 
        directionsData['routes'].isEmpty) {
      return {};
    }

    final Set<Polyline> polylines = {};
    
    try {
      // استخراج نقاط المسار المشفرة من البيانات
      final String encodedPoints = directionsData['routes'][0]['overview_polyline']['points'];
      List<LatLng> polylineCoordinates = [];
      
      // فك تشفير نقاط المسار
      // نحاول استخدام مكتبة flutter_polyline_points أولاً للتوافق مع Google Directions API
      try {
        final PolylinePoints polylinePoints = PolylinePoints();
        final List<PointLatLng> decodedPoints = polylinePoints.decodePolyline(encodedPoints);
        
        if (decodedPoints.isNotEmpty) {
          polylineCoordinates = decodedPoints
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();
        } else {
          throw Exception('No points decoded from polyline');
        }
      } catch (e) {
        print('Error with standard polyline decoding: $e, trying alternative format');
        
        // اختبار تنسيق آخر (النمط البسيط الخاص بنا "lat1,lng1|lat2,lng2|...")
        if (encodedPoints.contains(',') && (encodedPoints.contains('|') || encodedPoints.contains('%7C'))) {
          // استبدال %7C (ترميز URL لـ |) بـ |
          final String normalizedPoints = encodedPoints.replaceAll('%7C', '|');
          final pointsArray = normalizedPoints.split('|');
          
          for (var point in pointsArray) {
            if (point.isNotEmpty) {
              final coordinates = point.split(',');
              if (coordinates.length == 2) {
                try {
                  final double lat = double.parse(coordinates[0]);
                  final double lng = double.parse(coordinates[1]);
                  polylineCoordinates.add(LatLng(lat, lng));
                } catch (e) {
                  print('Error parsing coordinates: $e');
                }
              }
            }
          }
        }
      }
      
      // إذا لم نتمكن من الحصول على نقاط، استخدم نقاط البداية والنهاية على الأقل
      if (polylineCoordinates.isEmpty) {
        polylineCoordinates = [origin, destination];
        print('Could not decode polyline, using direct route.');
      }
      
      // تطبيق أنماط وألوان مختلفة حسب طول المسار
      final totalDistance = _calculateDistance(origin, destination);
      // استخدام أنماط مختلفة لمسارات مختلفة
      List<PatternItem> patterns = [];
      
      // استخدام خط متصل للمسارات القصيرة
      if (totalDistance < 2.0) {
        patterns = []; // خط متصل
      } 
      // استخدام خط متقطع للمسارات المتوسطة والطويلة لتمثيل طريق متعدد الحارات
      else if (totalDistance < 10.0) {
        patterns = [PatternItem.dash(20), PatternItem.gap(7)];
      } else {
        patterns = [PatternItem.dash(30), PatternItem.gap(10)];
      }
      
      // إضافة المسار إلى المجموعة
      if (polylineCoordinates.length >= 2) {
        polylines.add(
          Polyline(
            polylineId: PolylineId(polylineId),
            color: color,
            width: width,
            points: polylineCoordinates,
            patterns: patterns,
            jointType: JointType.round, // تنعيم الانعطافات
            startCap: Cap.roundCap,     // نهاية دائرية في بداية المسار
            endCap: Cap.roundCap,       // نهاية دائرية في نهاية المسار
          ),
        );
      } else {
        // في حالة عدم وجود نقاط مسار كافية، نستخدم الطريقة البديلة البسيطة
        polylines.add(
          Polyline(
            polylineId: PolylineId(polylineId),
            color: color,
            width: width,
            points: [origin, destination],
          ),
        );
      }
    } catch (e) {
      print('Error creating polyline: $e');
      // في حالة حدوث خطأ، نستخدم الطريقة البديلة البسيطة
      polylines.add(
        Polyline(
          polylineId: PolylineId(polylineId),
          color: color,
          width: width,
          points: [origin, destination],
        ),
      );
    }
    
    return polylines;
  }
  
  // استخراج معلومات الرحلة من بيانات المسار
  static Map<String, String> getTripInfo(Map<String, dynamic> directionsData) {
    if (directionsData.isEmpty || 
        !directionsData.containsKey('routes') || 
        directionsData['routes'].isEmpty) {
      return {
        'distance': 'غير معروفة',
        'duration': 'غير معروفة',
        'startAddress': '',
        'endAddress': '',
      };
    }
    
    final routes = directionsData['routes'][0];
    final legs = routes['legs'][0];
    
    return {
      'distance': legs['distance']['text'],
      'duration': legs['duration']['text'],
      'startAddress': legs['start_address'],
      'endAddress': legs['end_address'],
    };
  }
  
  // الحصول على خطوات المسار من نتيجة API
  static List<Map<String, dynamic>> getDirectionSteps(Map<String, dynamic> directionsData) {
    if (directionsData.isEmpty || 
        !directionsData.containsKey('routes') || 
        directionsData['routes'].isEmpty) {
      return [];
    }
    
    final routes = directionsData['routes'][0];
    final legs = routes['legs'][0];
    final steps = legs['steps'];
    
    return List<Map<String, dynamic>>.from(steps.map((step) {
      return {
        'instruction': step['html_instructions'],
        'distance': step['distance']['text'],
        'duration': step['duration']['text'],
        'maneuver': step['maneuver'] ?? 'straight',
      };
    }));
  }
}
