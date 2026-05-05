import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'auth_service.dart';
import 'vendor_order_service.dart';

class VendorOrdersPage extends StatefulWidget {
  final String? initialFilter;

  const VendorOrdersPage({Key? key, this.initialFilter}) : super(key: key);

  @override
  _VendorOrdersPageState createState() => _VendorOrdersPageState();
}

class _VendorOrdersPageState extends State<VendorOrdersPage> {
  String _selectedFilter = 'all';
  final VendorOrderService _orderService = VendorOrderService();

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter ?? 'all';
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final vendorId = authService.user!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Orders',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  SizedBox(width: 8),
                  _buildFilterChip('Pending', 'pending'),
                  SizedBox(width: 8),
                  _buildFilterChip('Shipped', 'shipped'),
                  SizedBox(width: 8),
                  _buildFilterChip('Completed', 'completed'),
                  SizedBox(width: 8),
                  _buildFilterChip('Cancelled', 'cancelled'),
                ],
              ),
            ),
          ),
          Divider(height: 1),

          // Orders List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _selectedFilter == 'all'
                  ? _orderService.getVendorOrders(vendorId)
                  : _orderService.getVendorOrdersByStatus(vendorId, _selectedFilter),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final orders = snapshot.data!.docs;

                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text(
                          _selectedFilter == 'all'
                              ? 'No orders yet'
                              : 'No $_selectedFilter orders',
                          style: GoogleFonts.poppins(fontSize: 20, color: Colors.grey[600]),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Orders will appear here',
                          style: GoogleFonts.poppins(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final data = order.data() as Map<String, dynamic>;

                    return VendorOrderCard(
                      orderId: order.id,
                      data: data,
                      onStatusUpdate: (newStatus) {
                        _orderService.updateOrderStatus(order.id, newStatus);
                      },
                      onTap: () {
                        _showOrderDetails(context, data, order.id);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _selectedFilter == value,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Colors.purple.withOpacity(0.2),
      checkmarkColor: Colors.purple,
      labelStyle: GoogleFonts.poppins(
        color: _selectedFilter == value ? Colors.purple : Colors.black87,
        fontWeight: _selectedFilter == value ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  void _showOrderDetails(BuildContext context, Map<String, dynamic> data, String orderId) {
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
          child: VendorOrderDetailsView(
            data: data,
            orderId: orderId,
            onStatusUpdate: (newStatus) {
              _orderService.updateOrderStatus(orderId, newStatus);
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }
}

class VendorOrderCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final Function(String) onStatusUpdate;
  final VoidCallback onTap;

  const VendorOrderCard({
    Key? key,
    required this.orderId,
    required this.data,
    required this.onStatusUpdate,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final items = data['items'] as List<dynamic>? ?? [];
    final totalAmount = data['totalAmount'] ?? 0;
    final status = data['status'] ?? 'pending';
    final customerName = data['customerName'] ?? 'Customer';
    final customerEmail = data['customerEmail'] ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    final date = createdAt != null
        ? DateFormat('MMM dd, yyyy - HH:mm').format(createdAt.toDate())
        : 'Unknown date';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${orderId.substring(0, 8)}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _getStatusColor(status)),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Customer: $customerName',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 4),
              Text(
                customerEmail,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 8),
              Text(
                date,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 8),
              Text(
                '${items.length} item${items.length != 1 ? 's' : ''} • Total: \$${totalAmount.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 12),

              // Quick Actions
              if (status == 'pending')
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onStatusUpdate('shipped'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: BorderSide(color: Colors.blue),
                        ),
                        child: Text('Mark as Shipped'),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onStatusUpdate('cancelled'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red),
                        ),
                        child: Text('Cancel'),
                      ),
                    ),
                  ],
                ),

              if (status == 'shipped')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => onStatusUpdate('completed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: Text('Mark as Completed'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'shipped':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

class VendorOrderDetailsView extends StatelessWidget {
  final Map<String, dynamic> data;
  final String orderId;
  final Function(String) onStatusUpdate;

  const VendorOrderDetailsView({
    Key? key,
    required this.data,
    required this.orderId,
    required this.onStatusUpdate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final items = data['items'] as List<dynamic>? ?? [];
    final totalAmount = data['totalAmount'] ?? 0;
    final status = data['status'] ?? 'pending';
    final customerName = data['customerName'] ?? 'Customer';
    final customerEmail = data['customerEmail'] ?? '';
    final customerPhone = data['customerPhone'] ?? 'Not provided';
    final createdAt = data['createdAt'] as Timestamp?;
    final date = createdAt != null
        ? DateFormat('MMM dd, yyyy - HH:mm').format(createdAt.toDate())
        : 'Unknown date';

    return Column(
      children: [
        // Header
        Container(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order Details',
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
                // Order Info
                _buildInfoRow('Order ID', '${orderId.substring(0, 8)}...'),
                _buildInfoRow('Date', date),
                _buildInfoRow('Status', status.toUpperCase(),
                    valueColor: _getStatusColor(status)),

                SizedBox(height: 20),

                // Customer Info
                Text(
                  'Customer Information',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 12),
                _buildInfoRow('Name', customerName),
                _buildInfoRow('Email', customerEmail),
                _buildInfoRow('Phone', customerPhone),

                SizedBox(height: 20),

                // Items
                Text(
                  'Items (${items.length})',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 12),

                ...items.map((item) => _buildOrderItem(item)).toList(),

                SizedBox(height: 20),

                // Total
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Amount:',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '\$${totalAmount.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                // Status Update Buttons
                if (status == 'pending')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update Status',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => onStatusUpdate('shipped'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                              ),
                              child: Text('Mark as Shipped'),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => onStatusUpdate('cancelled'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: Text('Cancel Order'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                if (status == 'shipped')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update Status',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => onStatusUpdate('completed'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: Text('Mark as Completed'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(dynamic item) {
    final name = item['name'] ?? 'Unknown Product';
    final price = item['price'] ?? 0;
    final quantity = item['quantity'] ?? 1;
    final image = item['image'] ?? '📦';
    final imageType = item['imageType'] ?? 'emoji';

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Product Image
          Container(
            width: 50,
            height: 50,
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
                  return Center(child: Icon(Icons.broken_image));
                },
              )
                  : Center(child: Text(image, style: TextStyle(fontSize: 20))),
            ),
          ),
          SizedBox(width: 12),

          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  'Quantity: $quantity',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Price: \$${price.toStringAsFixed(2)} each',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Total Price
          Text(
            '\$${(price * quantity).toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'shipped':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}