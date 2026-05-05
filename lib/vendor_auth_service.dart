import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'role_selection_page.dart';
import 'vendor_dashboard.dart';
import 'verify_email_page.dart';
import 'app.dart'; // Make sure to import your main customer app

class VendorAuthPage extends StatefulWidget {
  @override
  _VendorAuthPageState createState() => _VendorAuthPageState();
}

class _VendorAuthPageState extends State<VendorAuthPage> {
  bool _isLogin = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.purple.shade50, Colors.blue.shade50],
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
              child: IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => RoleSelectionPage()),
                      (Route<dynamic> route) => false,
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store, size: 64, color: Colors.purple),
                  SizedBox(height: 24),
                  Text(
                    _isLogin ? 'Vendor Login' : 'Become a Vendor',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.purple[800],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _isLogin
                        ? 'Access your vendor dashboard'
                        : 'Create your vendor account and start selling',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 32),
                  _isLogin ? _buildLoginForm() : _buildSignupForm(),
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLogin ? "Don't have an account? " : 'Already have an account? ',
                        style: GoogleFonts.poppins(color: Colors.grey[600]),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isLogin = !_isLogin;
                          });
                        },
                        child: Text(
                          _isLogin ? 'Sign Up' : 'Login',
                          style: GoogleFonts.poppins(
                            color: Colors.purple,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return VendorLoginForm();
  }

  Widget _buildSignupForm() {
    return VendorSignupForm();
  }
}

class VendorLoginForm extends StatefulWidget {
  @override
  _VendorLoginFormState createState() => _VendorLoginFormState();
}

class _VendorLoginFormState extends State<VendorLoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  DateTime? _lastLoginAttempt;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    // Rate limiting: prevent rapid successive login attempts
    final now = DateTime.now();
    if (_lastLoginAttempt != null) {
      final timeSinceLastAttempt = now.difference(_lastLoginAttempt!);
      if (timeSinceLastAttempt < Duration(seconds: 2)) {
        setState(() {
          _errorMessage = 'Please wait a moment before trying again.';
        });
        return;
      }
    }

    _lastLoginAttempt = now;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      // MANUAL NAVIGATION FALLBACK - Add this block
      print('Vendor login completed successfully');

      // Wait for role fetching to complete
      await Future.delayed(Duration(milliseconds: 1000));

      // Check current state directly
      final currentUser = FirebaseAuth.instance.currentUser;
      final authServiceInstance = Provider.of<AuthService>(context, listen: false);

      print('Vendor manual check - User: ${currentUser?.uid}');
      print('Vendor manual check - Role: ${authServiceInstance.userRole}');
      print('Vendor manual check - IsLoggedIn: ${authServiceInstance.isLoggedIn}');

      // If auth service indicates logged in, navigate manually
      if (currentUser != null) {
        print('Vendor manual navigation triggered');

        if (currentUser.emailVerified) {
          if (authServiceInstance.userRole == 'vendor') {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => VendorDashboard()),
                  (Route<dynamic> route) => false,
            );
          } else if (authServiceInstance.userRole == 'customer') {
            // This shouldn't happen for vendor login, but handle it
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => App()),
                  (Route<dynamic> route) => false,
            );
          } else {
            // Role not determined yet
            _showRoleLoading();
          }
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => VerifyEmailPage()),
                (Route<dynamic> route) => false,
          );
        }
      }

    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Login failed. Please try again.';

      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No vendor account found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many login attempts. Please wait 5-10 minutes and try again.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled. Please contact support.';
          break;
        default:
          errorMessage = e.message ?? 'Login failed. Please try again.';
      }

      setState(() {
        _errorMessage = errorMessage;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    }

    setState(() => _isLoading = false);
  }

  void _showRoleLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Determining Vendor Role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Please wait while we verify your vendor account...'),
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
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => VendorDashboard()),
              (Route<dynamic> route) => false,
        );
      } else if (authService.userRole == 'customer') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => App()),
              (Route<dynamic> route) => false,
        );
      } else {
        // Still no role, show error
        setState(() {
          _errorMessage = 'Unable to verify vendor account. Please contact support.';
        });
      }
    }
  }

  // Add a retry method for rate limiting
  Future<void> _retryLogin() async {
    if (_errorMessage.contains('Too many login attempts')) {
      // Wait 30 seconds before allowing retry
      await Future.delayed(Duration(seconds: 30));
      setState(() {
        _errorMessage = '';
      });
    } else {
      setState(() {
        _errorMessage = '';
      });
    }
  }

  Widget _buildErrorWidget() {
    final isRateLimitError = _errorMessage.contains('Too many login attempts');

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isRateLimitError ? Colors.orange[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isRateLimitError ? Colors.orange : Colors.red),
      ),
      child: Row(
        children: [
          Icon(
              isRateLimitError ? Icons.warning_amber : Icons.error_outline,
              color: isRateLimitError ? Colors.orange : Colors.red,
              size: 20
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage,
              style: GoogleFonts.poppins(
                  color: isRateLimitError ? Colors.orange[800] : Colors.red,
                  fontSize: 14
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_errorMessage.isNotEmpty)
          Column(
            children: [
              _buildErrorWidget(),
              if (_errorMessage.contains('Too many login attempts'))
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: TextButton(
                    onPressed: _isLoading ? null : _retryLogin,
                    child: Text(
                      'Wait 30 seconds and retry',
                      style: GoogleFonts.poppins(
                        color: Colors.purple,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter your email';
                      if (!value.contains('@')) return 'Please enter a valid email';
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter your password';
                      return null;
                    },
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Text(
                        'Login',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  if (_isLoading)
                    Text(
                      'Signing in...',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class VendorSignupForm extends StatefulWidget {
  @override
  _VendorSignupFormState createState() => _VendorSignupFormState();
}

class _VendorSignupFormState extends State<VendorSignupForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  DateTime? _lastSignupAttempt;

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match.';
      });
      return;
    }

    // Rate limiting: prevent rapid successive signup attempts
    final now = DateTime.now();
    if (_lastSignupAttempt != null) {
      final timeSinceLastAttempt = now.difference(_lastSignupAttempt!);
      if (timeSinceLastAttempt < Duration(seconds: 3)) {
        setState(() {
          _errorMessage = 'Please wait a moment before trying again.';
        });
        return;
      }
    }

    _lastSignupAttempt = now;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.vendorSignUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _companyNameController.text.trim(),
        _phoneController.text.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account created! Please check your email for verification.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );

      // Clear form after successful signup
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _companyNameController.clear();
      _phoneController.clear();

    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Registration failed. Please try again.';
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'An account already exists with this email.';
          break;
        case 'weak-password':
          errorMessage = 'Password is too weak. Please use a stronger password.';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many registration attempts. Please wait a few minutes and try again.';
          break;
        default:
          errorMessage = e.message ?? 'Registration failed. Please try again.';
      }
      setState(() {
        _errorMessage = errorMessage;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    }

    setState(() => _isLoading = false);
  }

  Widget _buildErrorWidget() {
    final isRateLimitError = _errorMessage.contains('Too many');

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isRateLimitError ? Colors.orange[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isRateLimitError ? Colors.orange : Colors.red),
      ),
      child: Row(
        children: [
          Icon(
              isRateLimitError ? Icons.warning_amber : Icons.error_outline,
              color: isRateLimitError ? Colors.orange : Colors.red,
              size: 20
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage,
              style: GoogleFonts.poppins(
                  color: isRateLimitError ? Colors.orange[800] : Colors.red,
                  fontSize: 14
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_errorMessage.isNotEmpty) _buildErrorWidget(),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _companyNameController,
                    decoration: InputDecoration(
                      labelText: 'Company Name',
                      prefixIcon: Icon(Icons.business),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter company name';
                      if (value.length < 2) return 'Company name must be at least 2 characters';
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter phone number';
                      if (value.length < 10) return 'Please enter a valid phone number';
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter your email';
                      if (!value.contains('@')) return 'Please enter a valid email';
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter a password';
                      if (value.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please confirm your password';
                      return null;
                    },
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Text(
                        'Create Account',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  if (_isLoading)
                    Text(
                      'Creating your account...',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _companyNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}