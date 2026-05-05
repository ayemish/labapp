import 'package:cloud_firestore/cloud_firestore.dart';

class VendorOrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates orders for each vendor from cart items during checkout
  Future<void> createOrdersFromCart({
    required String customerId,
    required String customerEmail,
    required String customerName,
    required String customerPhone,
    required List<Map<String, dynamic>> cartItems,
  }) async {
    try {
      // Group cart items by vendor
      final Map<String, List<Map<String, dynamic>>> itemsByVendor = {};

      for (var item in cartItems) {
        final vendorId = item['vendorId'] ?? 'unknown';

        if (!itemsByVendor.containsKey(vendorId)) {
          itemsByVendor[vendorId] = [];
        }
        itemsByVendor[vendorId]!.add(item);
      }

      // Create separate order for each vendor
      for (var entry in itemsByVendor.entries) {
        final vendorId = entry.key;
        final vendorItems = entry.value;

        // Calculate total for this vendor's items
        double vendorTotal = 0;
        for (var item in vendorItems) {
          vendorTotal += (item['price'] ?? 0) * (item['quantity'] ?? 1);
        }

        // Create order document
        await _firestore.collection('orders').add({
          'orderId': '',
          'customerId': customerId,
          'customerEmail': customerEmail,
          'customerName': customerName,
          'customerPhone': customerPhone,
          'vendorId': vendorId,
          'items': vendorItems.map((item) {
            return {
              'productId': item['productId'],
              'name': item['name'],
              'price': item['price'],
              'quantity': item['quantity'],
              'image': item['image'],
              'imageType': item['imageType'],
              'category': item['category'],
              'description': item['description'],
            };
          }).toList(),
          'totalAmount': vendorTotal,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }).then((docRef) {
          // Update order with its document ID
          docRef.update({'orderId': docRef.id});
        });
      }

      print('Orders created successfully for $customerId');
    } catch (e) {
      print('Error creating orders: $e');
      rethrow;
    }
  }

  /// Get all orders for a specific vendor
  Stream<QuerySnapshot> getVendorOrders(String vendorId) {
    return _firestore
        .collection('orders')
        .where('vendorId', isEqualTo: vendorId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get orders for a specific vendor filtered by status
  Stream<QuerySnapshot> getVendorOrdersByStatus(String vendorId, String status) {
    return _firestore
        .collection('orders')
        .where('vendorId', isEqualTo: vendorId)
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Update order status
  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Order $orderId status updated to $status');
    } catch (e) {
      print('Error updating order status: $e');
      rethrow;
    }
  }

  /// Get sales summary for a vendor (total orders and revenue)
  Future<Map<String, dynamic>> getVendorSalesSummary(String vendorId) async {
    try {
      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('vendorId', isEqualTo: vendorId)
          .get();

      int totalOrders = ordersSnapshot.docs.length;
      double totalRevenue = 0;
      int completedOrders = 0;

      for (var doc in ordersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalRevenue += (data['totalAmount'] ?? 0).toDouble();

        if (data['status'] == 'completed') {
          completedOrders++;
        }
      }

      return {
        'totalOrders': totalOrders,
        'completedOrders': completedOrders,
        'totalRevenue': totalRevenue,
        'pendingOrders': totalOrders - completedOrders,
      };
    } catch (e) {
      print('Error getting sales summary: $e');
      return {
        'totalOrders': 0,
        'completedOrders': 0,
        'totalRevenue': 0,
        'pendingOrders': 0,
      };
    }
  }
}
