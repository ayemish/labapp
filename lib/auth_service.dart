import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  bool _emailVerified = false;
  String _userRole = ''; // 'customer' or 'vendor'
  Map<String, dynamic>? _vendorData;

  // Prevent multiple simultaneous operations
  bool _isCheckingRole = false;
  bool _isSigningIn = false;
  bool _isSigningUp = false;
  StreamSubscription<User?>? _authSubscription;

  AuthService() {
    _initializeAuthListener();
  }

  // Separate method for cleaner initialization
  void _initializeAuthListener() {
    _authSubscription = _auth.authStateChanges().listen((User? user) async {
      // Prevent rapid successive calls
      if (_isCheckingRole) return;

      _user = user;
      if (user != null) {
        _emailVerified = user.emailVerified;
        _isCheckingRole = true;
        try {
          await _checkUserRole();
          print('Auth state changed - User: ${user.email}, Verified: ${user.emailVerified}, Role: $_userRole');
        } finally {
          _isCheckingRole = false;
        }
      } else {
        _emailVerified = false;
        _userRole = '';
        _vendorData = null;
      }
      // CRITICAL: Notify listeners only after all internal state is set
      notifyListeners();
    });
  }

  User? get user => _user;
  bool get isLoggedIn => _user != null && _emailVerified;
  bool get isEmailVerified => _emailVerified;
  bool get hasUnverifiedEmail => _user != null && !_emailVerified;
  String get userRole => _userRole;
  Map<String, dynamic>? get vendorData => _vendorData;

  Stream<User?> get userStream => _auth.authStateChanges();

  // Check user role from Firestore - REMOVED internal notifyListeners()
  Future<void> _checkUserRole() async {
    if (_user == null) return;

    try {
      print('Checking user role for: ${_user!.uid}');

      // Check vendor collection
      final vendorDoc = await _firestore.collection('vendors').doc(_user!.uid).get();
      if (vendorDoc.exists) {
        _userRole = 'vendor';
        _vendorData = vendorDoc.data();
        print('User role set to: vendor (internal)');
        return;
      }

      // Check customer collection
      final customerDoc = await _firestore.collection('customers').doc(_user!.uid).get();
      if (customerDoc.exists) {
        _userRole = 'customer';
        print('User role set to: customer (internal)');
        return;
      }

      // If no role found
      _userRole = '';
      print('No user role found for user: ${_user!.uid}');

    } catch (e) {
      print('Error checking user role: $e');
      _userRole = '';
    }
  }

  // Customer Sign Up
  Future<void> signUp(String email, String password) async {
    if (_isSigningUp) {
      print('Sign-up already in progress');
      return;
    }

    _isSigningUp = true;

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Add delay to avoid rapid requests
      await Future.delayed(Duration(milliseconds: 1000));

      await userCredential.user!.sendEmailVerification();
      print('Email verification sent to: $email');

      // Create customer document
      await _firestore.collection('customers').doc(userCredential.user!.uid).set({
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'emailVerified': false,
        'role': 'customer',
      });

      _userRole = 'customer';
      notifyListeners();
    } catch (e) {
      print('Signup error: $e');
      rethrow;
    } finally {
      _isSigningUp = false;
    }
  }

  // Vendor Sign Up
  Future<void> vendorSignUp(
      String email,
      String password,
      String companyName,
      String phone,
      ) async {
    if (_isSigningUp) {
      print('Vendor sign-up already in progress');
      return;
    }

    _isSigningUp = true;

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Add delay to avoid rapid requests
      await Future.delayed(Duration(milliseconds: 1000));

      await userCredential.user!.sendEmailVerification();
      print('Vendor verification email sent to: $email');

      // Create vendor document
      await _firestore.collection('vendors').doc(userCredential.user!.uid).set({
        'email': email,
        'companyName': companyName,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
        'emailVerified': false,
        'role': 'vendor',
      });

      _userRole = 'vendor';
      _vendorData = {
        'email': email,
        'companyName': companyName,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
        'emailVerified': false,
        'role': 'vendor',
      };
      notifyListeners();
    } catch (e) {
      print('Vendor signup error: $e');
      rethrow;
    } finally {
      _isSigningUp = false;
    }
  }

  // Sign In
  Future<void> signIn(String email, String password) async {
    // Prevent multiple simultaneous sign-in attempts
    if (_isSigningIn) {
      print('Sign-in already in progress');
      return;
    }

    _isSigningIn = true;

    try {
      print('=== SIGN IN STARTED ===');
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('Firebase sign in successful: ${userCredential.user?.email}');

      // Wait a moment before reloading to avoid rapid requests
      await Future.delayed(Duration(milliseconds: 500));

      await userCredential.user!.reload();
      _user = _auth.currentUser;
      _emailVerified = _user?.emailVerified ?? false;

      // Only send verification if not verified AND user exists
      if (_user != null && !_user!.emailVerified) {
        // Add delay before sending verification email
        await Future.delayed(Duration(milliseconds: 1000));
        await _user!.sendEmailVerification();
        print('Verification email sent to: ${_user!.email}');
      }

      // Check role with delay
      await Future.delayed(Duration(milliseconds: 500));
      await _checkUserRole();
      print('User role after sign in: $_userRole');

      notifyListeners();
      print('=== SIGN IN COMPLETED - LISTENERS NOTIFIED ===');

    } on FirebaseAuthException catch (e) {
      print('Signin error: $e');

      // Handle rate limiting specifically
      if (e.code == 'too-many-requests') {
        throw FirebaseAuthException(
          code: 'too-many-requests',
          message: 'Too many login attempts. Please wait a few minutes and try again.',
        );
      }
      rethrow;
    } catch (e) {
      print('Unexpected signin error: $e');
      rethrow;
    } finally {
      _isSigningIn = false;
    }
  }

  Future<void> signOut() async {
    try {
      print('Starting sign out process...');
      _emailVerified = false;
      _userRole = '';
      _vendorData = null;
      await _auth.signOut();
      print('Firebase sign out completed');
      notifyListeners(); // This triggers the AuthWrapper to rebuild
      print('Listeners notified after sign out');
    } catch (e) {
      print('Error during sign out: $e');
      rethrow;
    }
  }

  Future<bool> checkEmailVerified() async {
    try {
      if (_user == null) return false;

      await _user!.reload();
      _user = FirebaseAuth.instance.currentUser;

      _emailVerified = _user?.emailVerified ?? false;
      print('Email verification status refreshed: $_emailVerified');
      notifyListeners();

      return _emailVerified;
    } catch (e) {
      print('Error checking email verification: $e');
      return false;
    }
  }

  Future<void> resendVerificationEmail() async {
    if (_user != null && !_user!.emailVerified) {
      try {
        await _user!.sendEmailVerification();
        print('Resent email verification to: ${_user!.email}');
      } catch (e) {
        print('Error resending email verification: $e');
        rethrow;
      }
    }
  }

  // Cart Methods - UPDATED with vendorId
  Future<void> addToCart(
      String productId,
      String name,
      double price,
      String image, {
        String imageType = 'emoji',
        String category = '',
        String description = '',
        String vendorId = '', // ADDED: vendorId parameter
      }) async {
    if (_user == null) return;

    final cartRef = _firestore
        .collection('users')
        .doc(_user!.uid)
        .collection('cart')
        .doc(productId);

    final doc = await cartRef.get();
    if (doc.exists) {
      // Update quantity if already in cart
      await cartRef.update({
        'quantity': FieldValue.increment(1),
      });
    } else {
      // Add new item to cart with vendorId
      final cartItem = {
        'productId': productId,
        'name': name,
        'price': price,
        'image': image,
        'imageType': imageType,
        'category': category,
        'description': description,
        'vendorId': vendorId, // ADDED: vendorId
        'quantity': 1,
        'addedAt': FieldValue.serverTimestamp(),
      };
      await cartRef.set(cartItem);
    }
  }

  Future<void> removeFromCart(String productId) async {
    if (_user == null) return;

    await _firestore.collection('users').doc(_user!.uid).collection('cart').doc(productId).delete();
  }

  Future<void> updateCartQuantity(String productId, int quantity) async {
    if (_user == null) return;

    if (quantity <= 0) {
      await removeFromCart(productId);
    } else {
      await _firestore.collection('users').doc(_user!.uid).collection('cart').doc(productId).update({
        'quantity': quantity,
      });
    }
  }

  Stream<QuerySnapshot> getCartItems() {
    if (_user == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('users')
        .doc(_user!.uid)
        .collection('cart')
        .snapshots();
  }

  Future<int> getCartItemCount() async {
    if (_user == null) return 0;

    final snapshot = await _firestore
        .collection('users')
        .doc(_user!.uid)
        .collection('cart')
        .get();

    int totalCount = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalCount += (data['quantity'] as int? ?? 1);
    }
    return totalCount;
  }

  // NEW METHOD: Clear entire cart (used after checkout)
  Future<void> clearCart() async {
    if (_user == null) return;

    final cartSnapshot = await _firestore
        .collection('users')
        .doc(_user!.uid)
        .collection('cart')
        .get();

    final batch = _firestore.batch();
    for (var doc in cartSnapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
    print('Cart cleared for user: ${_user!.uid}');
  }

  // NEW METHOD: Get cart items as list for checkout
  Future<List<Map<String, dynamic>>> getCartItemsForCheckout() async {
    if (_user == null) return [];

    final cartSnapshot = await _firestore
        .collection('users')
        .doc(_user!.uid)
        .collection('cart')
        .get();

    return cartSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'productId': doc.id,
        'name': data['name'],
        'price': data['price'],
        'quantity': data['quantity'],
        'image': data['image'],
        'imageType': data['imageType'],
        'category': data['category'],
        'description': data['description'],
        'vendorId': data['vendorId'] ?? '', // Ensure vendorId is included
      };
    }).toList();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}