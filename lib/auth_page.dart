import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'login_page1.dart'; // Add this import for the new login page
import 'signup_page.dart'; // Add this import for the new signup page

class AuthPage extends StatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _showLoginPage = true;

  void _toggleAuthPage() {
    setState(() {
      _showLoginPage = !_showLoginPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                // Header Section
                _buildHeader(),
                SizedBox(height: 40),

                // Auth Form Section
                _showLoginPage
                    ? LoginPage1(onSwitchToSignup: _toggleAuthPage) // This should work now
                    : SignupPage(onSwitchToLogin: _toggleAuthPage),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Icon(
          Icons.shopping_bag_rounded,
          size: 80,
          color: Colors.blue,
        ),
        SizedBox(height: 16),
        Text(
          'Welcome to ShopApp',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
        SizedBox(height: 8),
        Text(
          _showLoginPage
              ? 'Sign up to your account'
              : 'Create your account',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}