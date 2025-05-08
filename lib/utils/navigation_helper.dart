import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../screens/client_interface.dart';
import '../screens/provider_interface.dart';

class NavigationHelper {
  // Función para navegar al usuario a la página correcta según su rol
  static void navigateBasedOnRole(BuildContext context, UserRole? role) {
    // Si el rol es nulo o no es un proveedor, navegar a la interfaz de cliente por defecto
    if (role == UserRole.provider) {
      // Si el usuario es un proveedor de servicios, navegar a la interfaz de proveedor
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => ServiceProviderHomePage()),
      );
    } else {
      // Si el usuario es un cliente (o admin que se maneja por defecto como cliente)
      // o si el rol es nulo (situación de error), ir a la interfaz de cliente por defecto
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => ClientHomePage()),
      );
    }
  }
}
