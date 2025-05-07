import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../screens/client_interface.dart';
import '../screens/provider_interface.dart';

class NavigationHelper {
  // Función para navegar al usuario a la página correcta según su rol
  static void navigateBasedOnRole(BuildContext context, UserRole role) {
    if (role == UserRole.provider) {
      // Si el usuario es un proveedor de servicios, navegar a la interfaz de proveedor
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => ServiceProviderHomePage()),
      );
    } else {
      // Si el usuario es un cliente (o admin que se maneja por defecto como cliente)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => ClientHomePage()),
      );
    }
  }
}
