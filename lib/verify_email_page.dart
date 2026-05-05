import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_service.dart';


class VerifyEmailPage extends StatefulWidget {
  @override
  _VerifyEmailPageState createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _isLoading = false;
  bool _isVerified = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  Timer? _verificationCheckTimer;
  String _debugInfo = '';

  @override
  void initState() {
    super.initState();
    _checkEmailSettings();
    _startAutoVerificationCheck();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _verificationCheckTimer?.cancel();
    super.dispose();
  }

  void _checkEmailSettings() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.user;

    setState(() {
      _debugInfo = 'User: ${user?.email}\nVerified: ${user?.emailVerified}';
    });
  }

  void _startAutoVerificationCheck() {
    // Check every 2 seconds if email is verified
    _verificationCheckTimer = Timer.periodic(Duration(seconds: 2), (_) {
      _checkVerification();
    });
  }

  Future<void> _checkVerification() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final verified = await authService.checkEmailVerified();

      if (verified && !_isVerified) {
        setState(() {
          _isVerified = verified;
          _debugInfo = 'Email verified successfully!';
        });

        // Cancel the timer once verified
        _verificationCheckTimer?.cancel();
      }
    } catch (e) {
      setState(() {
        _debugInfo = 'Error checking verification: $e';
      });
    }
  }

  void _startCooldown() {
    _resendCooldown = 60; // 60 seconds cooldown
    _cooldownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _resendCooldown--;
      });
      if (_resendCooldown <= 0) {
        timer.cancel();
      }
    });
  }

  Future<void> _resendVerification() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.resendVerificationEmail();

      _startCooldown();

      setState(() {
        _debugInfo = 'Verification email resent at ${DateTime.now()}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification email sent! Please check your inbox and spam folder.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      setState(() {
        _debugInfo = 'Error resending email: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending verification email: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _signOutAndReturn() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.signOut();
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.user;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Verify Email',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'debug') {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Debug Info'),
                    content: SingleChildScrollView(
                      child: Text(_debugInfo),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Close'),
                      ),
                    ],
                  ),
                );
              } else if (value == 'logout') {
                _signOutAndReturn();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'debug',
                child: Row(
                  children: [
                    Icon(Icons.bug_report, size: 20),
                    SizedBox(width: 8),
                    Text('Debug Info'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Header Icon
            Icon(
              _isVerified ? Icons.verified : Icons.email_outlined,
              size: 80,
              color: _isVerified ? Colors.green : Colors.blue,
            ),
            SizedBox(height: 24),

            // Title
            Text(
              _isVerified ? 'Email Verified!' : 'Verify Your Email',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: _isVerified ? Colors.green : Colors.blue[800],
              ),
            ),
            SizedBox(height: 16),

            // Email Address
            Text(
              user?.email ?? 'No email',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
            SizedBox(height: 16),

            if (!_isVerified) ...[
              // Instructions
              Text(
                'We sent a verification link to your email address.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Please check your inbox and spam folder.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Click the link in the email to verify your account.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Checking for verification automatically...',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.orange[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ] else ...[
              Text(
                'Your email has been successfully verified!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.green[700],
                ),
              ),
              SizedBox(height: 16),
              Text(
                'You will be redirected shortly...',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            SizedBox(height: 32),

            // Loading or Action Buttons
            _isLoading
                ? Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Processing...',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            )
                : Column(
              children: [
                if (!_isVerified) ...[
                  // Check Verification Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _checkVerification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'I\'ve Verified My Email',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Resend Verification Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _resendCooldown > 0 ? null : _resendVerification,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.blue),
                      ),
                      child: _resendCooldown > 0
                          ? Text(
                        'Resend in $_resendCooldown s',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      )
                          : Text(
                        'Resend Verification Email',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Continue to App Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/products');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Continue to App',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}