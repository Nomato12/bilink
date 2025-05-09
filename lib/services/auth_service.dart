import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:bilink/models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Estado de la autenticación
  bool isLoading = false;
  String? errorMessage;
  UserModel? _currentUser;

  // Variables para verificación por teléfono
  String? _verificationId;
  int? _resendToken;

  // Variable para prevenir múltiples solicitudes de verificación
  bool _isVerifying = false;
  bool get isVerifying => _isVerifying;

  // Obtener el usuario actual
  UserModel? get currentUser => _currentUser;

  // Obtener el estado de autenticación
  bool get isAuthenticated => _currentUser != null;

  // Constantes para el manejo de sesión
  static const String _lastLoginTimeKey = 'lastLoginTime';
  static const String _lastLoginIpKey = 'lastLoginIp';
  static const Duration _sessionDuration = Duration(
    days: 30,
  ); // مدة الجلسة 30 يوم للحفاظ على تسجيل الدخول لفترة أطول

  // Método para obtener la IP actual
  Future<String?> _getCurrentIp() async {
    try {
      final response = await http.get(Uri.parse('https://api.ipify.org'));
      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (e) {
      print('Error obteniendo la IP: $e');
    }
    return null;
  }

  // Método mejorado para verificar si hay un usuario ya loggeado
  Future<bool> checkPreviousLogin() async {
    try {
      final User? user = _auth.currentUser;
      final prefs = await SharedPreferences.getInstance();

      if (user != null) {
        // Verificar si hay datos de sesión guardados
        final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
        if (!isLoggedIn) return false;

        // Verificar el tiempo de la última sesión
        final int? lastLoginTime = prefs.getInt(_lastLoginTimeKey);
        if (lastLoginTime != null) {
          final DateTime lastLogin = DateTime.fromMillisecondsSinceEpoch(
            lastLoginTime,
          );
          final DateTime now = DateTime.now();

          // Si ha pasado más tiempo que la duración máxima de la sesión, cerrar sesión
          if (now.difference(lastLogin) > _sessionDuration) {
            print('Sesión expirada por tiempo');
            await logout();
            return false;
          }
        }

        // Verificar la IP de la última sesión
        final String? lastIp = prefs.getString(_lastLoginIpKey);
        final String? currentIp = await _getCurrentIp();

        if (lastIp != null && currentIp != null && lastIp != currentIp) {
          print('IP cambiada, cerrando sesión por seguridad');
          await logout();
          return false;
        }

        // Si todo está correcto, actualizar la información y cargar datos del usuario
        print('User found in Firebase Auth, fetching data from Firestore: ${user.uid}');
        await _fetchUserData(user.uid);
        
        // Verificación adicional para asegurar que obtuvimos los datos correctamente
        if (_currentUser == null || _currentUser!.uid.isEmpty) {
          print('ERROR: Failed to load user data from Firestore');
          return false;
        }

        // Actualizar timestamp de inicio de sesión
        await _updateLoginTimestamp();

        return true;
      }

      return false;
    } catch (e) {
      print('Error checking previous login: $e');
      return false;
    }
  }

  // Método para actualizar el timestamp de inicio de sesión
  Future<void> _updateLoginTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(_lastLoginTimeKey, now);

      // También actualizar la IP actual
      final String? currentIp = await _getCurrentIp();
      if (currentIp != null) {
        await prefs.setString(_lastLoginIpKey, currentIp);
      }

      // Si hay un usuario autenticado, actualizar también la información en Firestore
      if (_auth.currentUser != null) {
        await _firestore.collection('users').doc(_auth.currentUser!.uid).update(
          {'lastLogin': FieldValue.serverTimestamp(), 'lastIp': currentIp},
        );
      }
    } catch (e) {
      print('Error actualizando timestamp de sesión: $e');
    }
  }

  // Método para cargar los datos del usuario desde Firestore
  Future<void> _fetchUserData(String uid) async {
    try {
      if (uid.isEmpty) {
        print('ERROR: Attempting to fetch user data with empty UID');
        errorMessage = 'معرف المستخدم غير صحيح';
        notifyListeners();
        return;
      }
      
      print('Fetching user data for UID: $uid');
      
      // Obtener los datos del usuario desde Firestore
      final DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(uid).get();

      // Verificar si el documento existe
      if (userDoc.exists) {
        // Convertir los datos a un mapa
        final Map<String, dynamic> userData =
            userDoc.data() as Map<String, dynamic>;
            
        // Asegurar que el userData contenga el uid del documento
        if (!userData.containsKey('uid') || userData['uid'] == null || userData['uid'].toString().isEmpty) {
          print('Adding uid to user data from Firestore document ID: $uid');
          userData['uid'] = uid;
        }

        // Crear una instancia de UserModel con los datos obtenidos
        _currentUser = UserModel.fromMap(userData);
        
        print('User data loaded successfully for: ${_currentUser!.fullName} (${_currentUser!.uid})');
        
        // Notificar a los listeners sobre el cambio de estado
        notifyListeners();
      } else {
        // Si el usuario no existe en Firestore pero sí en Authentication
        print('Usuario autenticado no encontrado en Firestore: $uid');

        // Obtener datos básicos del usuario desde Authentication
        final User? authUser = _auth.currentUser;
        if (authUser != null) {
          // Crear un modelo básico con la información disponible
          _currentUser = UserModel(
            uid: authUser.uid, // Usar el UID de Firebase Auth
            email: authUser.email ?? '',
            fullName: authUser.displayName ?? '',
            phoneNumber: authUser.phoneNumber ?? '',
            role: UserRole.client, // Rol por defecto
            isPhoneVerified: authUser.phoneNumber != null,
          );

          // Asegurar que el UID se incluya en el mapa de datos para Firestore
          final userData = _currentUser!.toMap();
          userData['uid'] = authUser.uid; // Añadir el UID explícitamente al mapa
          
          // Guardar estos datos básicos en Firestore
          print('Creating new user document in Firestore with UID: ${authUser.uid}');
          await _firestore
              .collection('users')
              .doc(uid)
              .set(userData);

          notifyListeners();
        }
      }
    } catch (e) {
      print('Error obteniendo datos del usuario: $e');
      errorMessage = 'حدث خطأ في جلب بيانات المستخدم';
      notifyListeners();
    }
  }

  // Método para iniciar sesión con correo y contraseña
  Future<bool> loginWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      errorMessage = null;
      isLoading = true;
      notifyListeners();

      // Iniciar sesión con Firebase Auth
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        await _fetchUserData(userCredential.user!.uid);

        // Guardar la información de sesión localmente
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userId', userCredential.user!.uid);

        // Actualizar timestamp e IP de inicio de sesión
        await _updateLoginTimestamp();

        isLoading = false;
        notifyListeners();
        return true;
      }

      isLoading = false;
      notifyListeners();
      return false;
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'user-not-found':
          message = 'لم يتم العثور على مستخدم بهذا البريد الإلكتروني';
          break;
        case 'wrong-password':
          message = 'كلمة المرور غير صحيحة';
          break;
        case 'invalid-email':
          message = 'البريد الإلكتروني غير صالح';
          break;
        case 'user-disabled':
          message = 'تم تعطيل حساب المستخدم';
          break;
        case 'too-many-requests':
          message =
              'تم حظر الحساب مؤقتًا بسبب محاولات تسجيل دخول متكررة. حاول مرة أخرى لاحقًا.';
          break;
        default:
          message = 'حدث خطأ أثناء تسجيل الدخول: ${e.message}';
      }

      errorMessage = message;
      isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      errorMessage = 'حدث خطأ غير متوقع: $e';
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Método para registrarse con correo y contraseña
  Future<bool> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required UserRole role,
    String? companyName,
    Map<String, dynamic> additionalData = const {},
  }) async {
    try {
      errorMessage = null;
      isLoading = true;
      notifyListeners();

      // Crear usuario en Firebase Auth
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        // Crear el documento del usuario en Firestore
        final UserModel user = UserModel(
          uid: userCredential.user!.uid,
          email: email,
          fullName: fullName,
          phoneNumber: phoneNumber,
          role: role,
          companyName: companyName,
          isPhoneVerified: false,
          additionalData: additionalData,
        );

        await _firestore.collection('users').doc(user.uid).set(user.toMap());

        _currentUser = user;

        // Inicia el proceso de verificación telefónica
        await sendPhoneVerification(phoneNumber);

        isLoading = false;
        notifyListeners();
        return true;
      }

      isLoading = false;
      notifyListeners();
      return false;
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message = 'البريد الإلكتروني مستخدم بالفعل';
          break;
        case 'invalid-email':
          message = 'البريد الإلكتروني غير صالح';
          break;
        case 'weak-password':
          message = 'كلمة المرور ضعيفة جدًا';
          break;
        case 'operation-not-allowed':
          message = 'تسجيل البريد الإلكتروني وكلمة المرور غير مفعل';
          break;
        default:
          message = 'حدث خطأ أثناء إنشاء الحساب: ${e.message}';
      }

      errorMessage = message;
      isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      errorMessage = 'حدث خطأ غير متوقع: $e';
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Método para enviar la verificación de teléfono
  Future<bool> sendPhoneVerification(String phoneNumber) async {
    // Prevent multiple verification requests
    if (_isVerifying) {
      return false;
    }

    try {
      _isVerifying = true;
      errorMessage = null;
      isLoading = true;
      notifyListeners();

      // Asegurarse de que el número tenga el formato correcto con el código de país
      String formattedPhoneNumber = phoneNumber;
      if (!phoneNumber.startsWith('+')) {
        // Si no tiene el código de país, agregar +966 (código para Arabia Saudita)
        if (phoneNumber.startsWith('0')) {
          formattedPhoneNumber = '+966${phoneNumber.substring(1)}';
        } else {
          formattedPhoneNumber = '+966$phoneNumber';
        }
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verificación completada (Android solamente)
          // En algunos dispositivos Android, la verificación puede ser automática
          await _signInWithPhoneCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          String message;
          switch (e.code) {
            case 'invalid-phone-number':
              message = 'رقم الهاتف غير صالح';
              break;
            case 'too-many-requests':
              message = 'تم إرسال العديد من الطلبات. حاول مرة أخرى لاحقًا.';
              break;
            case 'app-not-authorized':
            case 'operation-not-allowed':
            case 'quota-exceeded':
              message = 'خدمة التحقق من الهاتف غير متوفرة حاليًا';
              break;
            case 'BILLING_NOT_ENABLED':
              message =
                  'لم يتم تفعيل الفوترة في Firebase. يرجى الاتصال بإدارة التطبيق';
              print('خطأ الفوترة: يجب تفعيل طريقة دفع في مشروع Firebase');
              break;
            default:
              message = 'فشل في إرسال رمز التحقق: ${e.message}';
          }

          errorMessage = message;
          isLoading = false;
          _isVerifying = false;
          notifyListeners();
        },
        codeSent: (String verificationId, int? resendToken) {
          // Código enviado al número de teléfono
          _verificationId = verificationId;
          _resendToken = resendToken;
          isLoading = false;
          _isVerifying = false; // Reset verification flag when code is sent
          notifyListeners();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Tiempo de espera para la recuperación automática del código
          _verificationId = verificationId;
          isLoading = false;
          _isVerifying = false; // Reset verification flag on timeout
          notifyListeners();
        },
        forceResendingToken: _resendToken,
      );

      return true;
    } catch (e) {
      isLoading = false;
      _isVerifying = false;
      if (e is FirebaseAuthException) {
        errorMessage = 'خطأ في إرسال رمز التحقق: ${e.message}';
      } else {
        errorMessage = 'خطأ في إرسال رمز التحقق: $e';
      }
      notifyListeners();
      return false;
    }
  }

  // Método para verificar el código de teléfono
  Future<bool> verifyPhoneCode(String smsCode) async {
    // Prevent multiple verification attempts
    if (_isVerifying || isLoading) {
      return false;
    }

    try {
      _isVerifying = true;
      errorMessage = null;
      isLoading = true;
      notifyListeners();

      if (_verificationId == null) {
        errorMessage = 'لم يتم إرسال رمز التحقق بعد';
        isLoading = false;
        _isVerifying = false;
        notifyListeners();
        return false;
      }

      // Create credential with the verification ID and SMS code
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      // Sign in with the phone credential
      await _signInWithPhoneCredential(credential);

      // Actualizar timestamp e IP de inicio de sesión
      await _updateLoginTimestamp();

      isLoading = false;
      _isVerifying = false; // Reset the verification flag
      notifyListeners();
      return true;
    } catch (e) {
      isLoading = false;
      _isVerifying = false; // Reset the verification flag even on error
      if (e is FirebaseAuthException) {
        if (e.code == 'invalid-verification-code') {
          errorMessage = 'فشل رمز التحقق: الرمز غير صحيح';
        } else {
          errorMessage = 'حدث خطأ أثناء التحقق: ${e.message}';
        }
      } else {
        errorMessage = 'حدث خطأ أثناء التحقق: $e';
      }
      notifyListeners();
      return false;
    }
  }

  // Método para iniciar sesión con credencial de teléfono
  Future<void> _signInWithPhoneCredential(
    PhoneAuthCredential credential,
  ) async {
    try {
      if (_auth.currentUser != null) {
        // Si ya hay un usuario autenticado, vincular el número de teléfono a la cuenta
        await _auth.currentUser!.linkWithCredential(credential);

        // Actualizar los datos del usuario en Firestore para indicar que el teléfono está verificado
        await _firestore.collection('users').doc(_auth.currentUser!.uid).update(
          {'isPhoneVerified': true},
        );

        // Actualizar el modelo de usuario local
        if (_currentUser != null) {
          _currentUser = _currentUser!.copyWith(isPhoneVerified: true);
          notifyListeners();
        }
      } else {
        // Si no hay usuario, iniciar sesión con la credencial de teléfono
        final UserCredential userCredential = await _auth.signInWithCredential(
          credential,
        );

        if (userCredential.user != null) {
          // Buscar los datos del usuario en Firestore
          await _fetchUserData(userCredential.user!.uid);

          // Actualizar información de sesión
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('userId', userCredential.user!.uid);

          // Actualizar timestamp e IP
          await _updateLoginTimestamp();
        }
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use') {
        throw Exception('رقم الهاتف مرتبط بالفعل بحساب آخر');
      } else {
        rethrow;
      }
    }
  }

  // Método para cerrar sesión
  Future<void> logout() async {
    try {
      await _auth.signOut();

      // Borrar el estado de sesión local
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);
      await prefs.remove('userId');

      // Eliminar también los datos de IP y timestamp
      await prefs.remove(_lastLoginTimeKey);
      await prefs.remove(_lastLoginIpKey);

      _currentUser = null;
      notifyListeners();
    } catch (e) {
      print('Error logging out: $e');
    }
  }

  // Método para restablecer la contraseña
  Future<bool> resetPassword(String email) async {
    try {
      errorMessage = null;
      isLoading = true;
      notifyListeners();

      // Enviar correo para restablecer contraseña
      await _auth.sendPasswordResetEmail(email: email);

      isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'invalid-email':
          message = 'البريد الإلكتروني غير صالح';
          break;
        case 'user-not-found':
          message = 'لم يتم العثور على مستخدم بهذا البريد الإلكتروني';
          break;
        default:
          message =
              'حدث خطأ أثناء إرسال رابط إعادة تعيين كلمة المرور: ${e.message}';
      }

      errorMessage = message;
      isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      errorMessage = 'حدث خطأ غير متوقع: $e';
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // تحديث بيانات المستخدم (الاسم، الإيميل، الهاتف)
  Future<void> updateProfile({
    String? fullName,
    String? email,
    String? phone,
  }) async {
    if (_auth.currentUser == null) return;
    final uid = _auth.currentUser!.uid;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      // تحديث البريد الإلكتروني في Firebase Auth إذا تغير
      if (email != null &&
          email.isNotEmpty &&
          email != _auth.currentUser!.email) {
        await _auth.currentUser!.updateEmail(email);
      }
      // تحديث الاسم في Firebase Auth
      if (fullName != null &&
          fullName.isNotEmpty &&
          fullName != _auth.currentUser!.displayName) {
        await _auth.currentUser!.updateDisplayName(fullName);
      }
      // تحديث الهاتف في Firestore فقط (تغيير الهاتف في Auth يتطلب تحقق جديد)
      final updateData = <String, dynamic>{};
      if (fullName != null && fullName.isNotEmpty) {
        updateData['fullName'] = fullName;
      }
      if (email != null && email.isNotEmpty) updateData['email'] = email;
      if (phone != null && phone.isNotEmpty) updateData['phoneNumber'] = phone;
      if (updateData.isNotEmpty) {
        await _firestore.collection('users').doc(uid).update(updateData);
      }
      // تحديث الكائن المحلي
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(
          fullName: fullName ?? _currentUser!.fullName,
          email: email ?? _currentUser!.email,
          phoneNumber: phone ?? _currentUser!.phoneNumber,
        );
        notifyListeners();
      }
    } on FirebaseAuthException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      rethrow;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // تحديث صورة الملف الشخصي
  Future<void> updateProfileImage(String imageUrl) async {
    try {
      final User? user = _auth.currentUser;
      
      if (user == null) {
        throw Exception('لا يوجد مستخدم مسجل الدخول');
      }
      
      // تحديث البيانات في Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'profileImageUrl': imageUrl,
      });
      
      // تحديث المستخدم الحالي محليًا
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(profileImageUrl: imageUrl);
        notifyListeners();
      }
      
      print('تم تحديث صورة الملف الشخصي بنجاح');
    } catch (e) {
      print('خطأ أثناء تحديث صورة الملف الشخصي: $e');
      throw e;
    }
  }
}
