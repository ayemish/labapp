import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'auth_page.dart';  // Changed from login_page.dart to auth_page.dart
import 'products_page.dart';

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    if (authService.isLoggedIn) {
      return ProductsPage();
    } else {
      return AuthPage();  // Changed from LoginPage() to AuthPage()
    }
  }
}