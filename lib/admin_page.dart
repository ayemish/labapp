import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({Key? key}) : super(key: key);

  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  bool _isLoading = false;
  String _message = '';

  Future<void> _addSampleProducts() async {
    setState(() {
      _isLoading = true;
      _message = 'Adding sample products...';
    });

    final sampleProducts = [
      {
        'name': 'Wireless Headphones',
        'price': 99.99,
        'description': 'High-quality wireless headphones with noise cancellation',
        'image': 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=500&h=500&fit=crop',
        'imageType': 'url',
        'category': 'Electronics',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Smart Watch',
        'price': 199.99,
        'description': 'Feature-rich smartwatch with health monitoring',
        'image': 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=500&h=500&fit=crop',
        'imageType': 'url',
        'category': 'Electronics',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Laptop Stand',
        'price': 49.99,
        'description': 'Adjustable laptop stand for ergonomic workspace',
        'image': 'https://images.unsplash.com/photo-1586953208448-b95a79798f07?w=500&h=500&fit=crop',
        'imageType': 'url',
        'category': 'Accessories',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Phone Case',
        'price': 29.99,
        'description': 'Durable and stylish phone case with drop protection',
        'image': 'https://images.unsplash.com/photo-1601593346740-925612772716?w=500&h=500&fit=crop',
        'imageType': 'url',
        'category': 'Accessories',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Bluetooth Speaker',
        'price': 79.99,
        'description': 'Portable Bluetooth speaker with crystal clear sound',
        'image': 'https://images.unsplash.com/photo-1608043152269-423dbba4e7e1?w=500&h=500&fit=crop',
        'imageType': 'url',
        'category': 'Electronics',
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Gaming Mouse',
        'price': 59.99,
        'description': 'High-precision gaming mouse with RGB lighting',
        'image': 'https://images.unsplash.com/photo-1527864550417-7fd91fc51a46?w=500&h=500&fit=crop',
        'imageType': 'url',
        'category': 'Electronics',
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    try {
      final firestore = FirebaseFirestore.instance;
      for (var product in sampleProducts) {
        await firestore.collection('products').add(product);
      }

      setState(() {
        _message = '✅ ${sampleProducts.length} sample products added successfully!';
      });
    } catch (e) {
      setState(() {
        _message = '❌ Error adding sample products: $e';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Sample Products', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Icon(
              Icons.inventory_2,
              size: 80,
              color: Colors.purple,
            ),
            SizedBox(height: 20),

            // Title
            Text(
              'Add Sample Products',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.purple,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),

            // Description
            Text(
              'This will add 6 sample products with high-quality images to your store.',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),

            // Product Preview Grid
            Container(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildProductPreview('Headphones', 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=300&h=300&fit=crop'),
                  _buildProductPreview('Smart Watch', 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=300&h=300&fit=crop'),
                  _buildProductPreview('Laptop Stand', 'https://images.unsplash.com/photo-1586953208448-b95a79798f07?w=300&h=300&fit=crop'),
                  _buildProductPreview('Phone Case', 'https://images.unsplash.com/photo-1601593346740-925612772716?w=300&h=300&fit=crop'),
                ],
              ),
            ),
            SizedBox(height: 30),

            // Message Display
            if (_message.isNotEmpty)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: _message.contains('✅') ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _message.contains('✅') ? Colors.green : Colors.red,
                  ),
                ),
                child: Text(
                  _message,
                  style: GoogleFonts.poppins(
                    color: _message.contains('✅') ? Colors.green[800] : Colors.red[800],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Add Sample Products Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _addSampleProducts,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(width: 12),
                    Text(
                      'Adding Products...',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_fix_high, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Add Sample Products',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Info Text
            Text(
              'Products include: Electronics, Accessories\nAll products come with high-quality images',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductPreview(String name, String imageUrl) {
    return Container(
      width: 100,
      margin: EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}