import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'app.dart'; // Make sure to import your main app pages
import 'vendor_dashboard.dart';
import 'verify_email_page.dart';

class LoginPage1 extends StatefulWidget {
  final VoidCallback onSwitchToSignup;
  final VoidCallback? onBack; // Added back callback

  const LoginPage1({Key? key, required this.onSwitchToSignup, this.onBack}) : super(key: key);

  @override
  _LoginPage1State createState() => _LoginPage1State();
}

class _LoginPage1State extends State<LoginPage1> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _login() async {
    print('Login button pressed'); // DEBUG

    if (!_formKey.currentState!.validate()) {
      print('Form validation failed'); // DEBUG
      return;
    }

    print('Form validation passed, starting login...'); // DEBUG

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      print('Calling authService.signIn...'); // DEBUG

      // CRITICAL: Await the sign-in which includes the role check
      await authService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      print('Login completed successfully'); // DEBUG

      // MANUAL NAVIGATION FALLBACK - Add this block
      await Future.delayed(Duration(milliseconds: 1000)); // Give time for role fetching

      // Check current state directly
      final currentUser = FirebaseAuth.instance.currentUser;
      final authServiceInstance = Provider.of<AuthService>(context, listen: false);

      print('Manual check - User: ${currentUser?.uid}');
      print('Manual check - Role: ${authServiceInstance.userRole}');
      print('Manual check - IsLoggedIn: ${authServiceInstance.isLoggedIn}');

      // If auth service indicates logged in, navigate manually
      if (currentUser != null) {
        print('Manual navigation triggered');

        if (currentUser.emailVerified) {
          if (authServiceInstance.userRole == 'vendor') {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => VendorDashboard()),
            );
          } else if (authServiceInstance.userRole == 'customer') {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => App()),
            );
          } else {
            // Role not determined yet, show loading
            _showRoleLoading();
          }
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => VerifyEmailPage()),
          );
        }
      }

    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code} - ${e.message}'); // DEBUG
      String errorMessage = 'Login failed. Please try again.';
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many attempts. Please try again later.';
          break;
        default:
          errorMessage = e.message ?? 'Login failed. Please try again.';
      }
      setState(() {
        _errorMessage = errorMessage;
      });
    } catch (e) {
      // Catch non-Firebase exceptions
      print('General error: $e'); // DEBUG
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      setState(() => _isLoading = false);
      print('Login process finished'); // DEBUG
    }
  }

  void _showRoleLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Determining Role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Please wait while we determine your account type...'),
          ],
        ),
      ),
    );

    // Check again after delay
    Future.delayed(Duration(seconds: 3), () {
      Navigator.of(context).pop();
      _checkRoleAgain();
    });
  }

  void _checkRoleAgain() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null && currentUser.emailVerified) {
      if (authService.userRole == 'vendor') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => VendorDashboard()),
        );
      } else if (authService.userRole == 'customer') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => App()),
        );
      } else {
        // Still no role, show error
        setState(() {
          _errorMessage = 'Unable to determine account type. Please contact support.';
        });
      }
    }
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Back Button - Added at the top
        if (widget.onBack != null)
          Container(
            width: double.infinity,
            child: Row(
              children: [
                IconButton(
                  onPressed: _handleBack,
                  icon: Icon(Icons.arrow_back, color: Colors.grey[700]),
                  padding: EdgeInsets.only(left: 8, bottom: 16),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

        // Error Message
        if (_errorMessage.isNotEmpty) _buildErrorWidget(),

        // Login Form
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 8),

                  SizedBox(height: 16),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                        'Sign In',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),


                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 20),

        // Switch to Signup
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account?",
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
              ),
            ),
            SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onSwitchToSignup,
              child: Text(
                'Sign Up',
                style: GoogleFonts.poppins(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage,
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}