import 'package:bilink/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../models/home_page.dart';
import 'dart:math' as math;
import 'package:confetti/confetti.dart';
import 'package:flutter/services.dart'; // Add import for haptic feedback

class PhoneVerificationPage extends StatefulWidget {
  final String phoneNumber;

  const PhoneVerificationPage({Key? key, required this.phoneNumber})
    : super(key: key);

  @override
  _PhoneVerificationPageState createState() => _PhoneVerificationPageState();
}

class _PhoneVerificationPageState extends State<PhoneVerificationPage>
    with TickerProviderStateMixin {
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isResending = false;
  int _resendTimer = 60;
  bool _canResend = false;
  bool _hasError = false;
  bool _verificationSuccess = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Shake animation controller for error feedback
  late final AnimationController _shakeController;
  late final Animation<Offset> _shakeAnimation;

  // Confetti controller
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _startResendTimer();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    // Initialize shake animation controller with improved animation
    _shakeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );

    // Create a more pronounced shaking effect
    _shakeAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(begin: Offset.zero, end: Offset(0.1, 0.0)),
        weight: 1.0,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(begin: Offset(0.1, 0.0), end: Offset(-0.1, 0.0)),
        weight: 2.0,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(begin: Offset(-0.1, 0.0), end: Offset(0.1, 0.0)),
        weight: 2.0,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(begin: Offset(0.1, 0.0), end: Offset(-0.1, 0.0)),
        weight: 2.0,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(begin: Offset(-0.1, 0.0), end: Offset.zero),
        weight: 1.0,
      ),
    ]).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );

    _shakeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.reset();
      }
    });

    // Initialize confetti controller
    _confettiController = ConfettiController(duration: Duration(seconds: 3));
  }

  void _startResendTimer() {
    setState(() {
      _canResend = false;
      _resendTimer = 60;
    });

    Future.delayed(Duration(seconds: 1), () {
      if (mounted && _resendTimer > 0) {
        setState(() {
          _resendTimer--;
        });
        _startResendTimer();
      } else if (mounted) {
        setState(() {
          _canResend = true;
        });
      }
    });
  }

  // Trigger shake animation with haptic feedback
  void _triggerShakeAnimation() {
    _shakeController.forward();
    HapticFeedback.mediumImpact(); // Add haptic feedback
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    if (authService.errorMessage != null && !_hasError) {
      setState(() {
        _hasError = true;
        _triggerShakeAnimation();
      });
    } else if (authService.errorMessage == null && _hasError) {
      setState(() {
        _hasError = false;
      });
    }

    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: TextStyle(
        fontSize: 22,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              _hasError
                  ? Colors.red.withOpacity(0.7)
                  : Colors.white.withOpacity(0.3),
        ),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: Colors.white.withOpacity(0.3),
        border: Border.all(
          color: _hasError ? Colors.red : Colors.white,
          width: 2,
        ),
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: Colors.white.withOpacity(0.3),
        border: Border.all(
          color: _hasError ? Colors.red.withOpacity(0.7) : Colors.white,
        ),
      ),
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF6B3B), Color(0xFFFF5775), Color(0xFF9B59B6)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Confetti Widget
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirection: math.pi / 2, // straight up
                  emissionFrequency: 0.05,
                  numberOfParticles: 20,
                  maxBlastForce: 20,
                  minBlastForce: 10,
                  gravity: 0.1,
                  shouldLoop: false,
                  colors: const [
                    Colors.green,
                    Colors.blue,
                    Colors.pink,
                    Colors.orange,
                    Colors.purple,
                    Colors.yellow,
                  ],
                ),
              ),
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: 50),

                      AnimatedContainer(
                        duration: Duration(milliseconds: 500),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _verificationSuccess
                              ? Icons.check_circle
                              : Icons.sms_outlined,
                          size: 64,
                          color: Colors.white,
                        ),
                      ),

                      SizedBox(height: 30),

                      Text(
                        'تحقق من رقم هاتفك',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      SizedBox(height: 16),

                      Text(
                        'تم إرسال رمز تحقق إلى ${widget.phoneNumber}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: 40),

                      if (authService.errorMessage != null)
                        AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          padding: EdgeInsets.all(12),
                          margin: EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.5),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      authService.errorMessage!,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (authService.errorMessage!.contains(
                                'فشل رمز التحقق',
                              ))
                                Padding(
                                  padding: EdgeInsets.only(top: 8, left: 30),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.lightbulb_outline,
                                            color: Colors.amber,
                                            size: 18,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'تأكد من إدخال الرمز الصحيح بالضبط كما استلمته في الرسالة النصية',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(
                                                  0.9,
                                                ),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.refresh_outlined,
                                            color: Colors.amber,
                                            size: 18,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'يمكنك إعادة إرسال الرمز بعد انتهاء المؤقت',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(
                                                  0.9,
                                                ),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.sms_outlined,
                                            color: Colors.amber,
                                            size: 18,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'تحقق من صندوق الرسائل للتأكد من استلام الرمز الأحدث',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(
                                                  0.9,
                                                ),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),

                      Form(
                        key: _formKey,
                        child: SlideTransition(
                          position: _shakeAnimation,
                          child: Pinput(
                            controller: _pinController,
                            length: 6,
                            defaultPinTheme: defaultPinTheme,
                            focusedPinTheme: focusedPinTheme,
                            submittedPinTheme: submittedPinTheme,
                            errorTextStyle: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            validator: (value) {
                              if (value == null ||
                                  value.isEmpty ||
                                  value.length < 6) {
                                return 'الرجاء إدخال رمز التحقق بالكامل';
                              }
                              return null;
                            },
                            pinputAutovalidateMode:
                                PinputAutovalidateMode.onSubmit,
                            showCursor: true,
                            onCompleted:
                                (pin) => _verifyPhone(authService, pin),
                            onChanged: (value) {
                              if (authService.errorMessage != null) {
                                authService.errorMessage = null;
                                setState(() {
                                  _hasError = false;
                                });
                              }
                            },
                          ),
                        ),
                      ),

                      SizedBox(height: 40),

                      AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        height: 55,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed:
                              authService.isLoading
                                  ? null
                                  : () => _verifyPhone(
                                    authService,
                                    _pinController.text,
                                  ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Color(0xFF9B59B6),
                            disabledBackgroundColor: Colors.white.withOpacity(
                              0.7,
                            ),
                            minimumSize: Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 0,
                          ),
                          child:
                              authService.isLoading
                                  ? SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF9B59B6),
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : Text(
                                    'تحقق',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                        ),
                      ),

                      SizedBox(height: 30),

                      _isResending
                          ? CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          )
                          : _canResend
                          ? Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: TextButton(
                              onPressed: () => _resendCode(authService),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: Text(
                                'إعادة إرسال الرمز',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                          : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'إعادة إرسال الرمز بعد ',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$_resendTimer',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                ' ثانية',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),

                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              // Success animation overlay
              if (_verificationSuccess)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.purple.withOpacity(0.5),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF9B59B6),
                                  size: 100,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _verifyPhone(AuthService authService, String code) async {
    if (_formKey.currentState!.validate()) {
      final success = await authService.verifyPhoneCode(code);

      if (!success && mounted) {
        // Trigger haptic feedback and shake animation for failed verification
        _triggerShakeAnimation();
      }

      if (success && mounted) {
        // Set success state and trigger animations
        setState(() {
          _verificationSuccess = true;
        });
        _animationController.forward();
        _confettiController.play(); // Play confetti animation

        // Show success snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('تم التحقق من رقم هاتفك بنجاح'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: EdgeInsets.all(8),
          ),
        );

        // Wait for animation before navigating
        Future.delayed(Duration(milliseconds: 2000), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => BiLinkHomePage()),
            );
          }
        });
      }
    }
  }

  Future<void> _resendCode(AuthService authService) async {
    setState(() {
      _isResending = true;
    });

    await authService.sendPhoneVerification(widget.phoneNumber);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إعادة إرسال رمز التحقق'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: EdgeInsets.all(8),
        ),
      );

      setState(() {
        _isResending = false;
        _pinController.clear();
      });
    }

    _startResendTimer();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _animationController.dispose();
    _shakeController.dispose(); // Dispose shake controller
    _confettiController.dispose(); // Dispose confetti controller
    super.dispose();
  }
}
