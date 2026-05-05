import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

class VendorAddProduct extends StatefulWidget {
  final String? productId;
  final Map<String, dynamic>? productData;

  const VendorAddProduct({
    Key? key,
    this.productId,
    this.productData,
  }) : super(key: key);

  @override
  _VendorAddProductState createState() => _VendorAddProductState();
}

class _VendorAddProductState extends State<VendorAddProduct> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  late TextEditingController _categoryController;
  late TextEditingController _imageController;
  late TextEditingController _stockController;

  bool _isLoading = false;
  String _imageType = 'emoji';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.productData?['name'] ?? '');
    _priceController = TextEditingController(
      text: (widget.productData?['price'] ?? '').toString(),
    );
    _descriptionController = TextEditingController(
      text: widget.productData?['description'] ?? '',
    );
    _categoryController = TextEditingController(
      text: widget.productData?['category'] ?? '',
    );
    _imageController = TextEditingController(
      text: widget.productData?['image'] ?? '📦',
    );
    _stockController = TextEditingController(
      text: (widget.productData?['stock'] ?? '0').toString(),
    );
    _imageType = widget.productData?['imageType'] ?? 'emoji';
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firestore = FirebaseFirestore.instance;

      final productData = {
        'name': _nameController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'description': _descriptionController.text.trim(),
        'category': _categoryController.text.trim(),
        'image': _imageController.text.trim(),
        'imageType': _imageType,
        'stock': int.parse(_stockController.text.trim()),
        'vendorId': authService.user!.uid,
        'vendorName': authService.vendorData?['companyName'] ?? 'Unknown',
      };

      if (widget.productId == null) {
        // Add new product
        productData['createdAt'] = FieldValue.serverTimestamp();
        await firestore.collection('products').add(productData);
        _showSuccessMessage('Product added successfully!');
      } else {
        // Update existing product
        productData['updatedAt'] = FieldValue.serverTimestamp();
        await firestore.collection('products').doc(widget.productId).update(productData);
        _showSuccessMessage('Product updated successfully!');
      }

      Future.delayed(Duration(seconds: 2), () {
        Navigator.pop(context);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving product: $e';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // URL validation method
  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.isAbsolute && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  bool _isImageUrl(String url) {
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'];
    return imageExtensions.any((ext) => url.toLowerCase().contains(ext));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.productId == null ? 'Add Product' : 'Edit Product',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            if (_errorMessage.isNotEmpty) _buildErrorWidget(),

            // Preview Section
            if (_imageType == 'url' && _imageController.text.isNotEmpty && _isValidUrl(_imageController.text))
              _buildImagePreview(),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Product Name
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Product Name',
                      prefixIcon: Icon(Icons.shopping_bag_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter product name';
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  // Price
                  TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      labelText: 'Price',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter price';
                      try {
                        double.parse(value);
                      } catch (e) {
                        return 'Please enter a valid price';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  // Category
                  TextFormField(
                    controller: _categoryController,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter category';
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.description_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter description';
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  // Stock
                  TextFormField(
                    controller: _stockController,
                    decoration: InputDecoration(
                      labelText: 'Stock (Optional)',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      helperText: 'Leave blank if not tracking stock',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        try {
                          int.parse(value);
                        } catch (e) {
                          return 'Please enter a valid number';
                        }
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  // Image Type
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Image Type',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile(
                                title: Text('Emoji'),
                                value: 'emoji',
                                groupValue: _imageType,
                                onChanged: (value) {
                                  setState(() {
                                    _imageType = value.toString();
                                    if (_imageType == 'emoji') {
                                      _imageController.text = '📦';
                                    }
                                  });
                                },
                              ),
                            ),
                            Expanded(
                              child: RadioListTile(
                                title: Text('URL'),
                                value: 'url',
                                groupValue: _imageType,
                                onChanged: (value) {
                                  setState(() {
                                    _imageType = value.toString();
                                    if (_imageType == 'url') {
                                      _imageController.text = '';
                                    }
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  // Image Input
                  TextFormField(
                    controller: _imageController,
                    decoration: InputDecoration(
                      labelText: _imageType == 'emoji' ? 'Image Emoji' : 'Image URL',
                      prefixIcon: Icon(Icons.image_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      helperText: _imageType == 'emoji'
                          ? 'Enter an emoji (e.g., 📱)'
                          : 'Enter image URL (https://...)',
                      suffixIcon: _imageType == 'url' && _imageController.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.visibility),
                        onPressed: () {
                          if (_isValidUrl(_imageController.text)) {
                            setState(() {});
                          }
                        },
                      )
                          : null,
                    ),
                    onChanged: (_) {
                      if (_imageType == 'url') {
                        setState(() {});
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter image';
                      }

                      if (_imageType == 'url') {
                        if (!_isValidUrl(value)) {
                          return 'Please enter a valid URL (https://example.com/image.jpg)';
                        }

                        if (!_isImageUrl(value)) {
                          return 'URL should point to an image file (.jpg, .png, .gif, etc.)';
                        }
                      }

                      return null;
                    },
                  ),
                  SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                        widget.productId == null ? 'Add Product' : 'Update Product',
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
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Image Preview:',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 8),
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _imageController.text,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, color: Colors.grey),
                          SizedBox(height: 4),
                          Text(
                            'Preview Failed',
                            style: GoogleFonts.poppins(fontSize: 10, color: Colors.red),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
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
              style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _imageController.dispose();
    _stockController.dispose();
    super.dispose();
  }
}