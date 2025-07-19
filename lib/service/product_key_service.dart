import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:question_bank/model/product_key.dart';

class ProductKeyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'customers';
  static const String _devicesCollection = 'device_registrations';

  /// Generate a unique 12-character product key
  String generateProductKey() {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final Random random = Random();
    String key = '';

    for (int i = 0; i < 12; i++) {
      key += chars[random.nextInt(chars.length)];
      // Add hyphen after every 4 characters for better readability
      if (i == 3 || i == 7) {
        key += '-';
      }
    }

    return key;
  }

  /// Check if a product key already exists
  Future<bool> doesProductKeyExist(String productKey) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('productKey', isEqualTo: productKey)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking product key existence: $e');
      return false;
    }
  }

  /// Generate a unique product key that doesn't exist in database
  Future<String> generateUniqueProductKey() async {
    String key;
    bool exists;

    do {
      key = generateProductKey();
      exists = await doesProductKeyExist(key);
    } while (exists);

    return key;
  }

  /// Create a new product key
  Future<ProductKeyModel> createProductKey({
    required String coachingName,
    required int subscriptionDurationMonths,
    required int maxDevices,
    required List<String> allowedStreams,
    required List<String> allowedLanguages,
    String? notes,
  }) async {
    try {
      final productKey = await generateUniqueProductKey();
      final now = DateTime.now();

      // Create the document reference first to get the ID
      final docRef = _firestore.collection(_collection).doc();
      final documentId = docRef.id;

      final keyModel = ProductKeyModel(
        keyId: documentId, // Set the document ID here
        productKey: productKey,
        coachingName: coachingName,
        subscriptionDurationMonths: subscriptionDurationMonths,
        maxDevices: maxDevices,
        allowedStreams: allowedStreams,
        allowedLanguages: allowedLanguages,
        createdAt: now,
        notes: notes,
      );

      // Create the document data including the document ID as a field
      final documentData = keyModel.toMap();
      documentData['documentId'] = documentId; // Store document ID as a field

      // Save to Firestore with the pre-generated document ID
      await docRef.set(documentData);

      debugPrint(
          'Product key created successfully: ${keyModel.productKey} with documentId: $documentId');
      return keyModel;
    } catch (e) {
      debugPrint('Failed to create product key: $e');
      throw Exception('Failed to create product key: $e');
    }
  }

  /// Activate a product key (first use)
  Future<ProductKeyModel> activateProductKey(String productKey, String deviceId,
      String deviceName, String deviceInfo) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('productKey', isEqualTo: productKey)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Product key not found');
      }

      final doc = querySnapshot.docs.first;
      final keyModel = ProductKeyModel.fromMap(doc.data(), doc.id);

      if (!keyModel.isActive) {
        throw Exception('Product key is disabled');
      }

      if (keyModel.isUsed) {
        throw Exception('Product key is already activated');
      }

      final now = DateTime.now();
      final expiresAt =
          now.add(Duration(days: keyModel.subscriptionDurationMonths * 30));

      // Update product key with first use
      await doc.reference.update({
        'firstUsedAt': now,
        'expiresAt': expiresAt,
        'currentDeviceCount': 1,
        'registeredDeviceIds': [deviceId],
      });

      // Register the device
      await _registerDevice(productKey, deviceId, deviceName, deviceInfo);

      debugPrint('Product key activated successfully: $productKey');
      return keyModel.copyWith(
        firstUsedAt: now,
        expiresAt: expiresAt,
        currentDeviceCount: 1,
        registeredDeviceIds: [deviceId],
      );
    } catch (e) {
      debugPrint('Failed to activate product key: $e');
      rethrow;
    }
  }

  /// Validate a product key for device access
  Future<ProductKeyModel?> validateProductKey(
      String productKey, String deviceId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('productKey', isEqualTo: productKey)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final doc = querySnapshot.docs.first;
      final keyModel = ProductKeyModel.fromMap(doc.data(), doc.id);

      // Check if key is active
      if (!keyModel.isActive) {
        throw Exception('Product key is disabled');
      }

      // Check if key is expired
      if (keyModel.isExpired) {
        throw Exception('Product key has expired');
      }

      // Check if device is registered
      if (!keyModel.registeredDeviceIds.contains(deviceId)) {
        // Try to register device if slots available
        if (keyModel.canAddDevice) {
          await _addDeviceToKey(doc.reference, deviceId);
          keyModel.registeredDeviceIds.add(deviceId);
          keyModel.currentDeviceCount++;
        } else {
          throw Exception('Maximum device limit reached');
        }
      }

      // Update last active time for device
      await _updateDeviceLastActive(productKey, deviceId);

      return keyModel;
    } catch (e) {
      debugPrint('Failed to validate product key: $e');
      rethrow;
    }
  }

  /// Add device to existing product key
  Future<void> _addDeviceToKey(
      DocumentReference keyRef, String deviceId) async {
    await keyRef.update({
      'registeredDeviceIds': FieldValue.arrayUnion([deviceId]),
      'currentDeviceCount': FieldValue.increment(1),
    });
  }

  /// Register a device
  Future<void> _registerDevice(String productKey, String deviceId,
      String deviceName, String deviceInfo) async {
    // Create the document reference first to get the ID
    final docRef = _firestore.collection(_devicesCollection).doc();
    final documentId = docRef.id;

    final deviceModel = DeviceRegistrationModel(
      registrationId: documentId, // Set the document ID here
      productKey: productKey,
      deviceId: deviceId,
      deviceName: deviceName,
      deviceInfo: deviceInfo,
      registeredAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
    );

    // Create the document data including the document ID as a field
    final documentData = deviceModel.toMap();
    documentData['documentId'] = documentId; // Store document ID as a field

    // Save to Firestore with the pre-generated document ID
    await docRef.set(documentData);
  }

  /// Update device last active time
  Future<void> _updateDeviceLastActive(
      String productKey, String deviceId) async {
    final querySnapshot = await _firestore
        .collection(_devicesCollection)
        .where('productKey', isEqualTo: productKey)
        .where('deviceId', isEqualTo: deviceId)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      await querySnapshot.docs.first.reference.update({
        'lastActiveAt': DateTime.now(),
      });
    }
  }

  /// Get all product keys
  Future<List<ProductKeyModel>> getAllProductKeys() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => ProductKeyModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Failed to get product keys: $e');
      throw Exception('Failed to get product keys: $e');
    }
  }

  /// Get product key by key string
  Future<ProductKeyModel?> getProductKeyByKey(String productKey) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('productKey', isEqualTo: productKey)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      return ProductKeyModel.fromMap(
        querySnapshot.docs.first.data(),
        querySnapshot.docs.first.id,
      );
    } catch (e) {
      debugPrint('Failed to get product key: $e');
      return null;
    }
  }

  /// Get product key by document ID
  Future<ProductKeyModel?> getProductKeyById(String documentId) async {
    try {
      final docSnapshot =
          await _firestore.collection(_collection).doc(documentId).get();

      if (!docSnapshot.exists) {
        return null;
      }

      return ProductKeyModel.fromMap(docSnapshot.data()!, docSnapshot.id);
    } catch (e) {
      debugPrint('Failed to get product key by ID: $e');
      return null;
    }
  }

  /// Disable/Enable product key
  Future<void> toggleProductKeyStatus(String keyId, bool isActive) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(keyId)
          .update({'isActive': isActive});

      debugPrint('Product key status updated: $isActive');
    } catch (e) {
      debugPrint('Failed to update product key status: $e');
      throw Exception('Failed to update product key status: $e');
    }
  }

  /// Update product key details
  Future<void> updateProductKey(ProductKeyModel keyModel) async {
    try {
      final updateData = keyModel.toMap();
      updateData['documentId'] =
          keyModel.keyId; // Ensure document ID is included

      await _firestore
          .collection(_collection)
          .doc(keyModel.keyId)
          .update(updateData);

      debugPrint('Product key updated successfully');
    } catch (e) {
      debugPrint('Failed to update product key: $e');
      throw Exception('Failed to update product key: $e');
    }
  }

  /// Delete product key
  Future<void> deleteProductKey(String keyId) async {
    try {
      // Get the product key first to find associated devices
      final keyDoc = await _firestore.collection(_collection).doc(keyId).get();

      if (keyDoc.exists) {
        final keyData = keyDoc.data()!;
        final productKey = keyData['productKey'];

        // Delete associated device registrations
        final deviceSnapshot = await _firestore
            .collection(_devicesCollection)
            .where('productKey', isEqualTo: productKey)
            .get();

        for (final doc in deviceSnapshot.docs) {
          await doc.reference.delete();
        }
      }

      // Delete the product key
      await _firestore.collection(_collection).doc(keyId).delete();

      debugPrint('Product key deleted successfully');
    } catch (e) {
      debugPrint('Failed to delete product key: $e');
      throw Exception('Failed to delete product key: $e');
    }
  }

  /// Get devices for a product key
  Future<List<DeviceRegistrationModel>> getDevicesForKey(
      String productKey) async {
    try {
      final querySnapshot = await _firestore
          .collection(_devicesCollection)
          .where('productKey', isEqualTo: productKey)
          .orderBy('registeredAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => DeviceRegistrationModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Failed to get devices: $e');
      return [];
    }
  }

  /// Get device by document ID
  Future<DeviceRegistrationModel?> getDeviceById(String documentId) async {
    try {
      final docSnapshot =
          await _firestore.collection(_devicesCollection).doc(documentId).get();

      if (!docSnapshot.exists) {
        return null;
      }

      return DeviceRegistrationModel.fromMap(
          docSnapshot.data()!, docSnapshot.id);
    } catch (e) {
      debugPrint('Failed to get device by ID: $e');
      return null;
    }
  }

  /// Remove device from product key
  Future<void> removeDeviceFromKey(String keyId, String deviceId) async {
    try {
      // Update product key
      await _firestore.collection(_collection).doc(keyId).update({
        'registeredDeviceIds': FieldValue.arrayRemove([deviceId]),
        'currentDeviceCount': FieldValue.increment(-1),
      });

      // Delete device registration
      final deviceSnapshot = await _firestore
          .collection(_devicesCollection)
          .where('deviceId', isEqualTo: deviceId)
          .get();

      for (final doc in deviceSnapshot.docs) {
        await doc.reference.delete();
      }

      debugPrint('Device removed from product key successfully');
    } catch (e) {
      debugPrint('Failed to remove device: $e');
      throw Exception('Failed to remove device: $e');
    }
  }

  /// Get product key statistics
  Future<Map<String, dynamic>> getProductKeyStats() async {
    try {
      final allKeys = await getAllProductKeys();

      final stats = <String, dynamic>{
        'totalKeys': allKeys.length,
        'activeKeys': allKeys.where((k) => k.isActive && !k.isExpired).length,
        'expiredKeys': allKeys.where((k) => k.isExpired).length,
        'disabledKeys': allKeys.where((k) => !k.isActive).length,
        'unusedKeys': allKeys.where((k) => !k.isUsed).length,
        'totalDevices':
            allKeys.fold<int>(0, (sum, k) => sum + k.currentDeviceCount),
      };

      return stats;
    } catch (e) {
      debugPrint('Failed to get product key stats: $e');
      return {
        'totalKeys': 0,
        'activeKeys': 0,
        'expiredKeys': 0,
        'disabledKeys': 0,
        'unusedKeys': 0,
        'totalDevices': 0,
      };
    }
  }

  /// Stream product keys for real-time updates
  Stream<List<ProductKeyModel>> streamProductKeys() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProductKeyModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Get customers by coaching name
  Future<List<ProductKeyModel>> getCustomersByCoachingName(
      String coachingName) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('coachingName', isEqualTo: coachingName)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => ProductKeyModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Failed to get customers by coaching name: $e');
      throw Exception('Failed to get customers by coaching name: $e');
    }
  }

  /// Search product keys by various criteria
  Future<List<ProductKeyModel>> searchProductKeys({
    String? productKey,
    String? coachingName,
    bool? isActive,
    bool? isExpired,
    bool? isUsed,
  }) async {
    try {
      Query query = _firestore.collection(_collection);

      if (productKey != null && productKey.isNotEmpty) {
        query = query.where('productKey', isEqualTo: productKey);
      }

      if (coachingName != null && coachingName.isNotEmpty) {
        query = query.where('coachingName', isEqualTo: coachingName);
      }

      if (isActive != null) {
        query = query.where('isActive', isEqualTo: isActive);
      }

      final querySnapshot =
          await query.orderBy('createdAt', descending: true).get();

      List<ProductKeyModel> results = querySnapshot.docs
          .map((doc) => ProductKeyModel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      // Apply additional filters that can't be done in Firestore query
      if (isExpired != null) {
        results = results.where((key) => key.isExpired == isExpired).toList();
      }

      if (isUsed != null) {
        results = results.where((key) => key.isUsed == isUsed).toList();
      }

      return results;
    } catch (e) {
      debugPrint('Failed to search product keys: $e');
      throw Exception('Failed to search product keys: $e');
    }
  }
}
