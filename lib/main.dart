import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:developer' as developer;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:bilink/screens/location_selection_screen_updated.dart';

import 'package:bilink/firebase_options.dart'; // Importar opciones de Firebase
import 'package:bilink/models/home_page.dart';
import 'package:bilink/services/auth_service.dart';
import 'package:bilink/services/fcm_service.dart'; // استيراد خدمة الإشعارات

void main() async {
  // Iniciar la aplicación en una zona de error controlada
  runZonedGuarded(
    () async {
      // Asegurarse de que las vinculaciones de Flutter se inicialicen dentro de la misma zona
      WidgetsFlutterBinding.ensureInitialized();      // Mejorar el manejo de errores para evitar mensajes corruptos
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        developer.log(
          'Flutter error caught',
          error: details.exception,
          stackTrace: details.stack,
        );
      };

      // Actualizar a la configuración de la UI más reciente para mejorar el rendimiento
      // Uso del API no-deprecado para manejar errores de plataforma
      ui.PlatformDispatcher.instance.onError = (error, stack) {
        developer.log('Platform error caught', error: error, stackTrace: stack);
        return true;
      };

      // Inicializar Firebase con las opciones configuradas
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // تهيئة خدمة الإشعارات
      final fcmService = FcmService();
      await fcmService.initialize();

      runApp(const MyApp());
    },
    (error, stack) {
      developer.log(
        'Uncaught error in runZonedGuarded',
        error: error,
        stackTrace: stack,
      );
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: MaterialApp(
        title: 'BiLink',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar', 'SA'), // Set Arabic locale
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ar', 'SA'), // Arabic
          Locale('en', 'US'), // English
        ],
        theme: ThemeData(
          primarySwatch: Colors.deepPurple,
          fontFamily: 'Cairo',
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF9B59B6),
            brightness: Brightness.light,
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // متحكمات الرسوم المتحركة
  late AnimationController _logoAnimationController;
  late AnimationController _textAnimationController;
  late AnimationController _particlesAnimationController;
  late AnimationController _progressAnimationController;

  // تعريف الرسوم المتحركة
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotateAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _titleSlideAnimation;
  late Animation<double> _subtitleSlideAnimation;
  late Animation<double> _progressAnimation;

  // متغيرات للجسيمات المتحركة
  final List<Map<String, dynamic>> _particles = [];
  final int _numberOfParticles = 20;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // إنشاء جسيمات متحركة عشوائية للخلفية
    _createParticles();

    // إعداد الرسوم المتحركة للشعار
    _logoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _logoScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.2,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
    ]).animate(_logoAnimationController);

    _logoRotateAnimation = Tween<double>(begin: 0.0, end: 2 * pi).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeInOutCubic),
      ),
    );

    // إعداد الرسوم المتحركة للنص
    _textAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textAnimationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
      ),
    );

    _titleSlideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _textAnimationController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _subtitleSlideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _textAnimationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // إعداد الرسوم المتحركة للجسيمات
    _particlesAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // إعداد شريط التقدم المتحرك
    _progressAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // تسلسل الرسوم المتحركة
    _startAnimationSequence();

    // الانتقال للصفحة المناسبة بعد انتهاء الرسوم المتحركة
    _checkAuthAndNavigate();

    // Listen for FCM foreground messages (location_request)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final data = message.data;
      if (data['type'] == 'location_request') {
        final navigator = Navigator.of(context, rootNavigator: true);
        // Show dialog to prompt user to share location
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('طلب مشاركة الموقع'),
            content: const Text('مزود الخدمة يطلب موقعك الحالي لتقديم الخدمة. هل ترغب في مشاركة موقعك؟'),
            actions: [
              TextButton(
                onPressed: () => navigator.pop(),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  navigator.pop();
                  // Open location picker
                  final result = await navigator.push(
                    MaterialPageRoute(
                      builder: (context) => const LocationSelectionScreen(),
                    ),
                  );
                  if (result != null && result is Map) {
                    final position = result['position'];
                    final address = result['address'] ?? '';
                    if (position != null) {
                      // Update user document in Firestore
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                          'location': {
                            'latitude': position.latitude,
                            'longitude': position.longitude,
                            'address': address,
                            'timestamp': FieldValue.serverTimestamp(),
                          },
                        });
                      }
                    }
                  }
                },
                child: const Text('مشاركة موقعي'),
              ),
            ],
          ),
        );
      }
    });
  }

  void _createParticles() {
    for (int i = 0; i < _numberOfParticles; i++) {
      _particles.add({
        'x': _random.nextDouble(),
        'y': _random.nextDouble(),
        'size': _random.nextDouble() * 15 + 5, // 5-20
        'speed': _random.nextDouble() * 0.02 + 0.01, // 0.01-0.03
        'opacity': _random.nextDouble() * 0.6 + 0.1, // 0.1-0.7
        'angle': _random.nextDouble() * 2 * pi,
      });
    }
  }

  Future<void> _startAnimationSequence() async {
    if (!mounted) return;
    // تحقق من أن الـ widget لا يزال مثبتًا قبل بدء الرسوم المتحركة

    // بدء الرسوم المتحركة للجسيمات
    if (!mounted) return;
    _particlesAnimationController.forward();

    // بدء الرسوم المتحركة للشعار
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _logoAnimationController.forward();

    // بدء الرسوم المتحركة للنص
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    _textAnimationController.forward();

    // بدء الرسوم المتحركة لشريط التقدم
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _progressAnimationController.forward();
  }

  @override
  void dispose() {
    // إيقاف جميع الرسوم المتحركة قبل التخلص منها
    if (_logoAnimationController.isAnimating) {
      _logoAnimationController.stop();
    }
    if (_textAnimationController.isAnimating) {
      _textAnimationController.stop();
    }
    if (_particlesAnimationController.isAnimating) {
      _particlesAnimationController.stop();
    }
    if (_progressAnimationController.isAnimating) {
      _progressAnimationController.stop();
    }

    _logoAnimationController.dispose();
    _textAnimationController.dispose();
    _particlesAnimationController.dispose();
    _progressAnimationController.dispose();
    super.dispose();
  }

  // التحقق من حالة تسجيل الدخول وتوجيه المستخدم للصفحة المناسبة
  Future<void> _checkAuthAndNavigate() async {
    // زيادة فترة عرض الشاشة الافتتاحية ليستمتع المستخدم بالتأثيرات المرئية
    await Future.delayed(const Duration(milliseconds: 4800));

    // Verificar si el widget aún está montado antes de continuar
    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);

    // Properly check if user is logged in
    bool isLoggedIn = false;
    try {
      isLoggedIn = await authService.checkPreviousLogin();
      print("Auth check result: User is ${isLoggedIn ? "logged in" : "not logged in"}");
      if (isLoggedIn && authService.currentUser != null) {
        print("Logged in user ID: ${authService.currentUser!.uid}");
        print("User role: ${authService.currentUser!.role}");
      }
    } catch (e) {
      print("Error checking authentication: $e");
      isLoggedIn = false;
    }

    // إذا لم يكن هناك مستخدم مسجل، ننتقل للصفحة الرئيسية
    // Asegurarse de que el widget todavía esté montado antes de navegar
    if (mounted) {
      // Detenemos todas las animaciones antes de navegar para evitar errores
      _logoAnimationController.stop();
      _textAnimationController.stop();
      _particlesAnimationController.stop();
      _progressAnimationController.stop();

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 1200),
          pageBuilder:
              (context, animation, secondaryAnimation) => BiLinkHomePage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curve = Curves.easeInOutCubic;
            final curveTween = CurveTween(curve: curve);
            final tween = Tween(begin: 0.0, end: 1.0).chain(curveTween);
            final opacityAnimation = animation.drive(tween);

            return FadeTransition(opacity: opacityAnimation, child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _logoAnimationController,
          _textAnimationController,
          _particlesAnimationController,
          _progressAnimationController,
        ]),
        builder: (context, _) {
          return Stack(
            children: [
              // خلفية متدرجة متحركة
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF7C3AED), // أرجواني داكن عصري
                      Color(0xFF5B21B6), // أرجواني متوسط
                      Color(0xFF4C1D95), // أرجواني غامق
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
                child: Stack(
                  children: [
                    // زخارف دائرية متوهجة للخلفية
                    Positioned(
                      top: -80,
                      right: -50,
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF9F7AEA).withOpacity(0.2),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF9F7AEA).withOpacity(0.3),
                              blurRadius: 80,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -120,
                      left: -60,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF7C3AED).withOpacity(0.15),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF7C3AED).withOpacity(0.2),
                              blurRadius: 100,
                              spreadRadius: 30,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // مؤثرات شبكية للخلفية
                    Opacity(
                      opacity: 0.07,
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage('assets/images/grid_pattern.png'),
                            repeat: ImageRepeat.repeat,
                            scale: 4.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // جسيمات متحركة
              ..._buildParticles(screenSize),

              // محتوى مركزي
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // شعار متحرك
                    Transform.rotate(
                      angle: _logoRotateAnimation.value,
                      child: Transform.scale(
                        scale: _logoScaleAnimation.value,
                        child: Container(
                          width: 240,
                          height: 240,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(
                                  0xFFa78bfa,
                                ).withOpacity(0.5 * _logoScaleAnimation.value),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/Design sans titre.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 30),

                    // عنوان متحرك
                    Transform.translate(
                      offset: Offset(0, _titleSlideAnimation.value),
                      child: Opacity(
                        opacity: _textFadeAnimation.value,
                        child: ShaderMask(
                          shaderCallback:
                              (bounds) => LinearGradient(
                                colors: [Colors.white, Color(0xFFddd6fe)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ).createShader(bounds),
                          child: Text(
                            'BiLink',
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),

                    // وصف متحرك
                    Transform.translate(
                      offset: Offset(0, _subtitleSlideAnimation.value),
                      child: Opacity(
                        opacity: _textFadeAnimation.value,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.15),
                                Colors.white.withOpacity(0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'منصة متكاملة لربط الشركات بخدمات النقل والتخزين',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 60),

                    // شريط تقدم متحرك
                    Opacity(
                      opacity: _textFadeAnimation.value,
                      child: SizedBox(
                        width: 240,
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: _progressAnimation.value,
                                minHeight: 6,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'جاري التحميل...',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // أشكال هندسية زخرفية
              Positioned(
                top: -50,
                right: -30,
                child: Transform.rotate(
                  angle: _particlesAnimationController.value * pi,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Color(0xFF8b5cf6).withOpacity(0.15),
                          Color(0xFF8b5cf6).withOpacity(0.0),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -80,
                left: -30,
                child: Transform.rotate(
                  angle: -_particlesAnimationController.value * pi,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Color(0xFFc4b5fd).withOpacity(0.1),
                          Color(0xFFc4b5fd).withOpacity(0.0),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildParticles(Size screenSize) {
    return _particles.map((particle) {
      // حساب الموضع الحالي بناءً على الرسوم المتحركة
      final double x =
          (particle['x'] +
              particle['speed'] *
                  cos(particle['angle']) *
                  _particlesAnimationController.value *
                  10) %
          1.0;
      final double y =
          (particle['y'] +
              particle['speed'] *
                  sin(particle['angle']) *
                  _particlesAnimationController.value *
                  10) %
          1.0;

      // حساب الشفافية المتغيرة مع الوقت
      final double opacity =
          particle['opacity'] *
          (0.5 + 0.5 * sin(_particlesAnimationController.value * 2 * pi));

      return Positioned(
        left: x * screenSize.width,
        top: y * screenSize.height,
        child: Container(
          width: particle['size'],
          height: particle['size'],
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(opacity),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(opacity * 0.3),
                blurRadius: particle['size'],
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}
