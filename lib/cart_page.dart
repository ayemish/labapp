import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'auth_service.dart';
import 'vendor_order_service.dart';
import 'order_history_page.dart';

class CartPage extends StatelessWidget {
  const CartPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Shopping Cart', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: authService.getCartItems(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final cartItems = snapshot.data!.docs;

          if (cartItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    'Your cart is empty',
                    style: GoogleFonts.poppins(fontSize: 20, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add some products to get started',
                    style: GoogleFonts.poppins(color: Colors.grey[500]),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Continue Shopping'),
                  ),
                ],
              ),
            );
          }

          // Calculate total
          double total = 0;
          for (var item in cartItems) {
            final data = item.data() as Map<String, dynamic>;
            final price = data['price'] ?? 0;
            final quantity = data['quantity'] ?? 1;
            total += (price as num) * quantity;
          }

          return Column(
            children: [
              // Cart Items List
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    final data = item.data() as Map<String, dynamic>;
                    final productId = item.id;
                    final name = data['name'] ?? 'Unknown Product';
                    final price = data['price'] ?? 0;
                    final quantity = data['quantity'] ?? 1;
                    final image = data['image'] ?? '📦';
                    final imageType = data['imageType'] ?? 'emoji';
                    final category = data['category'] ?? '';
                    final description = data['description']?.toString() ?? 'No description available';
                    final vendorId = data['vendorId'] ?? '';

                    return CartItemCard(
                      productId: productId,
                      name: name,
                      price: price,
                      quantity: quantity,
                      image: image,
                      imageType: imageType,
                      category: category,
                      description: description,
                      vendorId: vendorId,
                      onQuantityChanged: (newQuantity) {
                        authService.updateCartQuantity(productId, newQuantity);
                      },
                      onRemove: () {
                        authService.removeFromCart(productId);
                      },
                      onViewProduct: () {
                        _showProductDetailsFromCart(
                          context,
                          name,
                          price,
                          image,
                          imageType,
                          category,
                          description,
                          productId,
                          vendorId,
                          authService,
                        );
                      },
                    );
                  },
                ),
              ),

              // Total and Checkout Section
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey[300]!)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total:',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '\$${total.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          // Show delivery options first, then proceed with original checkout
                          bool proceed = await _showDeliveryOptions(context, total);
                          if (proceed) {
                            await _processCheckout(context, authService, cartItems, total);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Checkout',
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
          );
        },
      ),
    );
  }

  // Delivery options dialog with location and payment
  Future<bool> _showDeliveryOptions(BuildContext context, double total) async {
    String selectedPaymentMethod = 'cash_on_delivery';
    String selectedLocation = 'current_location';
    String address = '';
    bool isLoadingLocation = false;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Delivery & Payment', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order Total
                    Text(
                      'Order Total: \$${total.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                    SizedBox(height: 20),

                    // Delivery Location Section
                    Text(
                      'Delivery Location',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 12),

                    // Current Location Option
                    ListTile(
                      leading: Icon(Icons.my_location, color: Colors.blue),
                      title: Text('Use Current Location', style: GoogleFonts.poppins()),
                      subtitle: isLoadingLocation
                          ? Text('Getting your location...', style: TextStyle(color: Colors.orange))
                          : Text(address.isEmpty ? 'Tap to get current location' : address),
                      trailing: Radio<String>(
                        value: 'current_location',
                        groupValue: selectedLocation,
                        onChanged: (value) async {
                          setState(() {
                            selectedLocation = value!;
                            isLoadingLocation = true;
                          });

                          // Get current location
                          try {
                            Position position = await Geolocator.getCurrentPosition(
                              desiredAccuracy: LocationAccuracy.high,
                            );

                            List<Placemark> placemarks = await placemarkFromCoordinates(
                              position.latitude,
                              position.longitude,
                            );

                            Placemark placemark = placemarks.first;
                            String currentAddress = '${placemark.street}, ${placemark.locality}, ${placemark.administrativeArea}';

                            setState(() {
                              address = currentAddress;
                              isLoadingLocation = false;
                            });
                          } catch (e) {
                            setState(() {
                              address = 'Unable to get location. Please enable location services.';
                              isLoadingLocation = false;
                            });
                          }
                        },
                      ),
                      onTap: () async {
                        setState(() {
                          selectedLocation = 'current_location';
                          isLoadingLocation = true;
                        });

                        // Get current location
                        try {
                          Position position = await Geolocator.getCurrentPosition(
                            desiredAccuracy: LocationAccuracy.high,
                          );

                          List<Placemark> placemarks = await placemarkFromCoordinates(
                            position.latitude,
                            position.longitude,
                          );

                          Placemark placemark = placemarks.first;
                          String currentAddress = '${placemark.street}, ${placemark.locality}, ${placemark.administrativeArea}';

                          setState(() {
                            address = currentAddress;
                            isLoadingLocation = false;
                          });
                        } catch (e) {
                          setState(() {
                            address = 'Unable to get location. Please enable location services.';
                            isLoadingLocation = false;
                          });
                        }
                      },
                    ),

                    // Manual Address Option
                    ListTile(
                      leading: Icon(Icons.location_on, color: Colors.green),
                      title: Text('Enter Address Manually', style: GoogleFonts.poppins()),
                      subtitle: Text('Type your delivery address'),
                      trailing: Radio<String>(
                        value: 'manual_address',
                        groupValue: selectedLocation,
                        onChanged: (value) async {
                          setState(() {
                            selectedLocation = value!;
                          });

                          // Show address input dialog
                          String? manualAddress = await showDialog<String>(
                            context: context,
                            builder: (context) => AddressInputDialog(),
                          );

                          if (manualAddress != null && manualAddress.isNotEmpty) {
                            setState(() {
                              address = manualAddress;
                            });
                          }
                        },
                      ),
                      onTap: () async {
                        setState(() {
                          selectedLocation = 'manual_address';
                        });

                        // Show address input dialog
                        String? manualAddress = await showDialog<String>(
                          context: context,
                          builder: (context) => AddressInputDialog(),
                        );

                        if (manualAddress != null && manualAddress.isNotEmpty) {
                          setState(() {
                            address = manualAddress;
                          });
                        }
                      },
                    ),

                    // Show selected address
                    if (address.isNotEmpty)
                      Container(
                        margin: EdgeInsets.only(top: 8),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                address,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.green[800],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    SizedBox(height: 20),

                    // Payment Methods Section
                    Text(
                      'Payment Method',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 12),

                    // Cash on Delivery
                    ListTile(
                      leading: Icon(Icons.money_off, color: Colors.green),
                      title: Text('Cash on Delivery', style: GoogleFonts.poppins()),
                      subtitle: Text('Pay when you receive your order'),
                      trailing: Radio<String>(
                        value: 'cash_on_delivery',
                        groupValue: selectedPaymentMethod,
                        onChanged: (value) {
                          setState(() {
                            selectedPaymentMethod = value!;
                          });
                        },
                      ),
                      onTap: () {
                        setState(() {
                          selectedPaymentMethod = 'cash_on_delivery';
                        });
                      },
                    ),

                    // JazzCash
                    ListTile(
                      leading: Icon(Icons.phone_android, color: Colors.red),
                      title: Text('JazzCash', style: GoogleFonts.poppins()),
                      subtitle: Text('Pay securely with JazzCash'),
                      trailing: Radio<String>(
                        value: 'jazzcash',
                        groupValue: selectedPaymentMethod,
                        onChanged: (value) {
                          setState(() {
                            selectedPaymentMethod = value!;
                          });
                        },
                      ),
                      onTap: () {
                        setState(() {
                          selectedPaymentMethod = 'jazzcash';
                        });
                      },
                    ),

                    // Credit/Debit Card
                    ListTile(
                      leading: Icon(Icons.credit_card, color: Colors.blue),
                      title: Text('Credit/Debit Card', style: GoogleFonts.poppins()),
                      subtitle: Text('Pay with your bank card'),
                      trailing: Radio<String>(
                        value: 'card',
                        groupValue: selectedPaymentMethod,
                        onChanged: (value) {
                          setState(() {
                            selectedPaymentMethod = value!;
                          });
                        },
                      ),
                      onTap: () {
                        setState(() {
                          selectedPaymentMethod = 'card';
                        });
                      },
                    ),

                    // Show map preview if location is available
                    if (address.isNotEmpty && address != 'Unable to get location. Please enable location services.')
                      Container(
                        margin: EdgeInsets.only(top: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Location Preview',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 8),
                            Container(
                              height: 150,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.map, size: 40, color: Colors.blue),
                                    SizedBox(height: 8),
                                    Text(
                                      'Map Preview',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Delivery to:',
                                      style: GoogleFonts.poppins(fontSize: 12),
                                    ),
                                    Text(
                                      address.length > 30 ? '${address.substring(0, 30)}...' : address,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel', style: GoogleFonts.poppins()),
                ),
                ElevatedButton(
                  onPressed: address.isNotEmpty
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: Text(
                      'Proceed with ${_getPaymentMethodName(selectedPaymentMethod)}',
                      style: GoogleFonts.poppins(color: Colors.white)
                  ),
                ),
              ],
            );
          },
        );
      },
    ) ?? false;
  }

  String _getPaymentMethodName(String method) {
    switch (method) {
      case 'cash_on_delivery': return 'Cash on Delivery';
      case 'jazzcash': return 'JazzCash';
      case 'card': return 'Card';
      default: return 'Cash on Delivery';
    }
  }

  // ORIGINAL CHECKOUT PROCESS - COMPLETELY UNCHANGED
  Future<void> _processCheckout(BuildContext context, AuthService authService, List<QueryDocumentSnapshot> cartSnapshot, double total) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get current user data
      final user = authService.user;
      if (user == null) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please login to checkout'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      print('Starting checkout for user: ${user.uid}');

      // Convert cart items to order format
      List<Map<String, dynamic>> cartItems = [];
      for (var doc in cartSnapshot) {
        final data = doc.data() as Map<String, dynamic>;

        String? vendorId = data['vendorId'];
        print('Cart item ${doc.id}: vendorId = $vendorId');

        // If vendorId not in cart, fetch from products collection
        if (vendorId == null || vendorId.isEmpty) {
          try {
            final productDoc = await FirebaseFirestore.instance
                .collection('products')
                .doc(doc.id)
                .get();

            if (productDoc.exists) {
              final productData = productDoc.data() as Map<String, dynamic>;
              vendorId = productData['vendorId'];
              print('Fetched vendorId from products collection: $vendorId');
            }
          } catch (e) {
            print('Error fetching product: $e');
          }
        }

        // Only add item if vendorId is found
        if (vendorId != null && vendorId.isNotEmpty) {
          cartItems.add({
            'productId': doc.id,
            'name': data['name'],
            'price': data['price'],
            'quantity': data['quantity'] ?? 1,
            'image': data['image'],
            'imageType': data['imageType'],
            'category': data['category'],
            'description': data['description'],
            'vendorId': vendorId,
          });
          print('✓ Added item: ${data['name']} from vendor: $vendorId');
        } else {
          print('✗ Skipped item ${doc.id} - no vendorId found');
        }
      }

      // Check if we have any valid items
      if (cartItems.isEmpty) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Products missing vendor information. Please clear cart and re-add products.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      print('Total cart items with vendorId: ${cartItems.length}');

      // Create orders using VendorOrderService
      final orderService = VendorOrderService();
      await orderService.createOrdersFromCart(
        customerId: user.uid,
        customerEmail: user.email ?? '',
        customerName: user.displayName ?? 'Customer',
        customerPhone: 'Not provided',
        cartItems: cartItems,
      );

      print('Orders created successfully');

      // Clear the cart after successful checkout
      for (var item in cartSnapshot) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cart')
            .doc(item.id)
            .delete();
      }

      print('Cart cleared');

      Navigator.pop(context); // Close loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order placed successfully! Total: \$${total.toStringAsFixed(2)}'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Navigate back to products
      Navigator.popUntil(context, (route) => route.isFirst);

    } catch (e) {
      print('Checkout error: $e');
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error placing order: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showProductDetailsFromCart(
      BuildContext context,
      String name,
      double price,
      String image,
      String imageType,
      String category,
      String description,
      String productId,
      String vendorId,
      AuthService authService,
      ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Header with close button
              Container(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Product Details',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(height: 1),

              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Image
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey[100],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: imageType == 'url'
                              ? Image.network(
                            image,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image, color: Colors.grey, size: 50),
                                    SizedBox(height: 8),
                                    Text(
                                      'Failed to load image',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                              : Center(
                            child: Text(
                              image,
                              style: TextStyle(fontSize: 80),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),

                      // Product Name
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),

                      // Category
                      if (category.isNotEmpty)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            category,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.blue[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      SizedBox(height: 16),

                      // Price
                      Text(
                        '\$${price.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(height: 16),

                      // Description
                      Text(
                        'Description',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        description,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action Buttons
              Container(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Add More Button
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () {
                            authService.addToCart(
                              productId,
                              name,
                              price,
                              image,
                              imageType: imageType,
                              category: category,
                              description: description,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$name added to cart!'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.blue),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'Add More',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),

                    // View in Products Button
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); // Close details
                            // Navigate back to products page
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.store, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'View in Store',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Address Input Dialog
class AddressInputDialog extends StatefulWidget {
  @override
  _AddressInputDialogState createState() => _AddressInputDialogState();
}

class _AddressInputDialogState extends State<AddressInputDialog> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _zipCodeController = TextEditingController();

  @override
  void dispose() {
    _addressController.dispose();
    _cityController.dispose();
    _zipCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Enter Delivery Address', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Street Address',
                hintText: 'Enter your street address',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            SizedBox(height: 12),
            TextField(
              controller: _cityController,
              decoration: InputDecoration(
                labelText: 'City',
                hintText: 'Enter your city',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _zipCodeController,
              decoration: InputDecoration(
                labelText: 'ZIP Code (Optional)',
                hintText: 'Enter ZIP code',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            String address = _addressController.text.trim();
            String city = _cityController.text.trim();
            String zipCode = _zipCodeController.text.trim();

            if (address.isNotEmpty && city.isNotEmpty) {
              String fullAddress = '$address, $city';
              if (zipCode.isNotEmpty) {
                fullAddress += ', $zipCode';
              }
              Navigator.of(context).pop(fullAddress);
            }
          },
          child: Text('Save Address'),
        ),
      ],
    );
  }
}

class CartItemCard extends StatelessWidget {
  final String productId;
  final String name;
  final double price;
  final int quantity;
  final String image;
  final String imageType;
  final String category;
  final String description;
  final String vendorId;
  final Function(int) onQuantityChanged;
  final VoidCallback onRemove;
  final VoidCallback onViewProduct;

  const CartItemCard({
    Key? key,
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.image,
    required this.imageType,
    required this.category,
    required this.description,
    required this.vendorId,
    required this.onQuantityChanged,
    required this.onRemove,
    required this.onViewProduct,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Top Row: Image and Product Info
            Row(
              children: [
                // Product Image (tappable)
                InkWell(
                  onTap: onViewProduct,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[100],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imageType == 'url'
                          ? Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, color: Colors.grey, size: 20),
                                SizedBox(height: 2),
                                Text(
                                  'Failed',
                                  style: GoogleFonts.poppins(
                                    fontSize: 7,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                          : Center(
                        child: Text(
                          image,
                          style: TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),

                // Product Details - Expanded to take remaining space
                Expanded(
                  child: InkWell(
                    onTap: onViewProduct,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          '\$${price.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Total: \$${(price * quantity).toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // View Product Button
                IconButton(
                  icon: Icon(Icons.visibility, color: Colors.blue),
                  onPressed: onViewProduct,
                  tooltip: 'View Product Details',
                ),
              ],
            ),

            SizedBox(height: 12),

            // Bottom Row: Quantity Controls and Remove Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Quantity Controls
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove, size: 18),
                        onPressed: quantity > 1 ? () => onQuantityChanged(quantity - 1) : null,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(minWidth: 36),
                      ),
                      Container(
                        width: 30,
                        child: Center(
                          child: Text(
                            quantity.toString(),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add, size: 18),
                        onPressed: () => onQuantityChanged(quantity + 1),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(minWidth: 36),
                      ),
                    ],
                  ),
                ),

                // Remove Button
                TextButton(
                  onPressed: onRemove,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Remove',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}