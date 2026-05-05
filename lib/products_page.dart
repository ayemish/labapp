import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'cart_page.dart';
import 'order_history_page.dart';

class ProductsPage extends StatefulWidget {
  @override
  _ProductsPageState createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _sortBy = 'name';
  final TextEditingController _searchController = TextEditingController();
  bool _isDarkMode = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DocumentSnapshot> _filterAndSortProducts(List<DocumentSnapshot> products) {
    var filtered = products.where((product) {
      final data = product.data() as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString().toLowerCase();
      final category = (data['category'] ?? '').toString().toLowerCase();
      final description = (data['description'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();

      final matchesSearch = name.contains(query) ||
          category.contains(query) ||
          description.contains(query);
      final matchesCategory =
          _selectedCategory == 'All' || category == _selectedCategory.toLowerCase();

      return matchesSearch && matchesCategory;
    }).toList();

    // Sort
    filtered.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;

      switch (_sortBy) {
        case 'price_low':
          return (dataA['price'] ?? 0).compareTo(dataB['price'] ?? 0);
        case 'price_high':
          return (dataB['price'] ?? 0).compareTo(dataA['price'] ?? 0);
        case 'name':
        default:
          return (dataA['name'] ?? '')
              .toString()
              .compareTo((dataB['name'] ?? '').toString());
      }
    });

    return filtered;
  }

  List<String> _getCategories(List<DocumentSnapshot> products) {
    final categories = {'All'};
    for (var product in products) {
      final data = product.data() as Map<String, dynamic>;
      final category = data['category'] ?? 'Uncategorized';
      categories.add(category);
    }
    return categories.toList();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.user;
    final isDark = _isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? Color(0xFF1E1E1E) : Colors.white,
      appBar: AppBar(
        title: Text(
          'Products',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isDark ? Color(0xFF2C2C2C) : Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Dark Mode Toggle
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
            tooltip: 'Toggle Dark Mode',
          ),

          // Order History Icon
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => OrderHistoryPage()),
              );
            },
            tooltip: 'Order History',
          ),

          // Cart Icon with Badge
          StreamBuilder<QuerySnapshot>(
            stream: authService.getCartItems(),
            builder: (context, snapshot) {
              int itemCount = 0;
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  itemCount += (data['quantity'] as int? ?? 1);
                }
              }

              return Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.shopping_cart),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CartPage()),
                      );
                    },
                  ),
                  if (itemCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints:
                        BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          itemCount > 99 ? '99+' : itemCount.toString(),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          // Logout Button
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async => await authService.signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              color: isDark ? Color(0xFF2C2C2C) : Colors.blue[50],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome!',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.blue[800],
                    ),
                  ),
                  Text(
                    user?.email ?? 'User',
                    style: GoogleFonts.poppins(
                      color: isDark ? Colors.grey[400] : Colors.blue[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Search and Filter Section
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      prefixIcon: Icon(Icons.search,
                          color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      filled: true,
                      fillColor: isDark ? Color(0xFF2C2C2C) : Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),

                  SizedBox(height: 12),

                  // Filter and Sort Row
                  Row(
                    children: [
                      // Category Filter
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Color(0xFF2C2C2C) : Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCategory,
                              isExpanded: true,
                              icon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              style: GoogleFonts.poppins(
                                color: isDark ? Colors.white : Colors.black,
                                fontSize: 14,
                              ),
                              dropdownColor: isDark ? Color(0xFF2C2C2C) : Colors.white,
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedCategory = newValue!;
                                });
                              },
                              items: <String>['All', 'Electronics', 'Clothing', 'Books', 'Home', 'Sports']
                                  .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(width: 12),

                      // Sort Button
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? Color(0xFF2C2C2C) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: PopupMenuButton<String>(
                          onSelected: (value) {
                            setState(() {
                              _sortBy = value;
                            });
                          },
                          itemBuilder: (BuildContext context) => [
                            PopupMenuItem<String>(
                              value: 'name',
                              child: Text('Sort by Name', style: GoogleFonts.poppins()),
                            ),
                            PopupMenuItem<String>(
                              value: 'price_low',
                              child: Text('Price: Low to High', style: GoogleFonts.poppins()),
                            ),
                            PopupMenuItem<String>(
                              value: 'price_high',
                              child: Text('Price: High to Low', style: GoogleFonts.poppins()),
                            ),
                          ],
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Icon(Icons.sort, color: isDark ? Colors.grey[400] : Colors.grey[600], size: 20),
                                SizedBox(width: 4),
                                Text('Sort', style: GoogleFonts.poppins(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontSize: 14,
                                )),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Product Grid
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child: Text('Error: ${snapshot.error}',
                            style: TextStyle(
                                color:
                                isDark ? Colors.white : Colors.black)));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  var products = snapshot.data!.docs;
                  var filteredProducts = _filterAndSortProducts(products);
                  var categories = _getCategories(products);

                  // Update dropdown items with actual categories from Firestore
                  if (_selectedCategory == 'All' && categories.isNotEmpty) {
                    // Already set to All
                  }

                  return Padding(
                    padding: EdgeInsets.all(16),
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                        MediaQuery.of(context).size.width > 600 ? 3 : 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        final productData =
                        product.data() as Map<String, dynamic>;

                        return ProductCard(
                          product: productData,
                          productId: product.id,
                          authService: authService,
                          isDarkMode: isDark,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final String productId;
  final AuthService authService;
  final bool isDarkMode;

  const ProductCard({
    required this.product,
    required this.productId,
    required this.authService,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final imageType = product['imageType'] ?? 'emoji';
    final image = product['image'] ?? '📦';
    final vendorName = product['vendorName'] ?? 'Unknown Vendor';

    return Card(
      elevation: 3,
      color: isDarkMode ? Color(0xFF2C2C2C) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showProductDetails(context, product, productId),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageType == 'url'
                      ? Image.network(
                    image,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: isDarkMode ? Color(0xFF3C3C3C) : Colors.grey[200],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image,
                                color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                                size: 30),
                            SizedBox(height: 4),
                            Text(
                              'No Image',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                      : Center(
                      child: Text(image, style: TextStyle(fontSize: 40))),
                ),
              ),
              SizedBox(height: 6),

              // Product name
              Text(product['name'] ?? 'Unnamed Product',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),

              // Vendor name
              Text('by $vendorName',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  )),
              SizedBox(height: 4),

              // Price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('\$${(product['price'] ?? 0).toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, color: Colors.blue)),
                  IconButton(
                    icon: Icon(Icons.add_shopping_cart,
                        size: 18, color: Colors.blue),
                    onPressed: () {
                      authService.addToCart(
                        productId,
                        product['name'] ?? 'Unknown Product',
                        (product['price'] ?? 0).toDouble(),
                        product['image'] ?? '📦',
                        imageType: product['imageType'] ?? 'emoji',
                        category: product['category'] ?? '',
                        description:
                        product['description'] ?? 'No description available',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('${product['name']} added to cart!'),
                        backgroundColor: Colors.green,
                      ));
                    },
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProductDetails(
      BuildContext context, Map<String, dynamic> product, String productId) {
    final imageType = product['imageType'] ?? 'emoji';
    final image = product['image'] ?? '📦';
    final vendorName = product['vendorName'] ?? 'Unknown Vendor';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: imageType == 'url'
                        ? Image.network(image,
                        height: 200, width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            color: isDarkMode ? Color(0xFF3C3C3C) : Colors.grey[200],
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image,
                                    color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                                    size: 50),
                                SizedBox(height: 8),
                                Text(
                                  'Failed to load image',
                                  style: GoogleFonts.poppins(
                                    color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        })
                        : Center(
                        child:
                        Text(image, style: TextStyle(fontSize: 80)))),
                SizedBox(height: 16),

                // Name
                Text(product['name'] ?? 'Unnamed Product',
                    style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black)),
                SizedBox(height: 6),

                // Vendor
                Text('Sold by $vendorName',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[700])),

                SizedBox(height: 16),
                Text(product['description'] ?? 'No description available',
                    style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[700])),

                Spacer(),

                // Price + Add Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${(product['price'] ?? 0).toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        authService.addToCart(
                          productId,
                          product['name'] ?? 'Unknown Product',
                          (product['price'] ?? 0).toDouble(),
                          product['image'] ?? '📦',
                          imageType: product['imageType'] ?? 'emoji',
                          category: product['category'] ?? '',
                          description:
                          product['description'] ?? 'No description',
                        );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('${product['name']} added to cart!'),
                          backgroundColor: Colors.green,
                        ));
                      },
                      icon: Icon(Icons.add_shopping_cart),
                      label: Text('Add to Cart'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding:
                        EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}