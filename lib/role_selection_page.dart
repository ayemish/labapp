import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_page.dart';
import 'vendor_auth_service.dart'; // Reverting to your specified file name

class RoleSelectionPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade50, Colors.purple.shade50],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo/Title
                Icon(
                  Icons.shopping_bag,
                  size: 80,
                  color: Colors.blue,
                ),
                SizedBox(height: 24),

                Text(
                  'Welcome to ShopApp',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue[800],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),

                Text(
                  'Choose your role to get started',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 60),

                // Customer Card
                _buildRoleCard(
                  context,
                  icon: Icons.person_outline,
                  title: 'Customer',
                  subtitle: 'Browse and buy products',
                  color: Colors.blue,
                  onTap: () {
                    // FIX: Use pushAndRemoveUntil for complete screen replacement
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => AuthPage()),
                          (Route<dynamic> route) => false, // Remove all previous routes
                    );
                  },
                ),
                SizedBox(height: 20),

                // Vendor Card
                _buildRoleCard(
                  context,
                  icon: Icons.store_outlined,
                  title: 'Vendor',
                  subtitle: 'Sell your products',
                  color: Colors.purple,
                  onTap: () {
                    // FIX: Use pushAndRemoveUntil for complete screen replacement
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => VendorAuthPage()),
                          (Route<dynamic> route) => false, // Remove all previous routes
                    );
                  },
                ),

                SizedBox(height: 60),

                // Info Text
                Text(
                  'By continuing, you agree to our Terms of Service',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required Color color,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: color,
              ),
            ),
            SizedBox(height: 16),

            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 8),

            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Get Started',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, color: color, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}