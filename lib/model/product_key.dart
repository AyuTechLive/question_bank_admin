import 'package:cloud_firestore/cloud_firestore.dart';

class ProductKeyModel {
  String? keyId;
  String productKey;
  String coachingName;
  int subscriptionDurationMonths;
  int maxDevices;
  List<String> allowedStreams;
  List<String> allowedLanguages;
  bool isActive;
  DateTime createdAt;
  DateTime? firstUsedAt;
  DateTime? expiresAt;
  int currentDeviceCount;
  List<String> registeredDeviceIds;
  String? notes;
  String createdBy;

  ProductKeyModel({
    this.keyId,
    required this.productKey,
    required this.coachingName,
    required this.subscriptionDurationMonths,
    required this.maxDevices,
    required this.allowedStreams,
    required this.allowedLanguages,
    this.isActive = true,
    required this.createdAt,
    this.firstUsedAt,
    this.expiresAt,
    this.currentDeviceCount = 0,
    this.registeredDeviceIds = const [],
    this.notes,
    this.createdBy = 'admin',
  });

  Map<String, dynamic> toMap() {
    return {
      'keyId': keyId,
      'documentId': keyId, // Store document ID as a field for easy reference
      'productKey': productKey,
      'coachingName': coachingName,
      'subscriptionDurationMonths': subscriptionDurationMonths,
      'maxDevices': maxDevices,
      'allowedStreams': allowedStreams,
      'allowedLanguages': allowedLanguages,
      'isActive': isActive,
      'createdAt': createdAt,
      'firstUsedAt': firstUsedAt,
      'expiresAt': expiresAt,
      'currentDeviceCount': currentDeviceCount,
      'registeredDeviceIds': registeredDeviceIds,
      'notes': notes,
      'createdBy': createdBy,
    };
  }

  factory ProductKeyModel.fromMap(Map<String, dynamic> map, String docId) {
    return ProductKeyModel(
      keyId: docId,
      productKey: map['productKey'] ?? '',
      coachingName: map['coachingName'] ?? '',
      subscriptionDurationMonths: map['subscriptionDurationMonths'] ?? 0,
      maxDevices: map['maxDevices'] ?? 1,
      allowedStreams: List<String>.from(map['allowedStreams'] ?? []),
      allowedLanguages: List<String>.from(map['allowedLanguages'] ?? []),
      isActive: map['isActive'] ?? true,
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      firstUsedAt: map['firstUsedAt']?.toDate(),
      expiresAt: map['expiresAt']?.toDate(),
      currentDeviceCount: map['currentDeviceCount'] ?? 0,
      registeredDeviceIds: List<String>.from(map['registeredDeviceIds'] ?? []),
      notes: map['notes'],
      createdBy: map['createdBy'] ?? 'admin',
    );
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isUsed {
    return firstUsedAt != null;
  }

  bool get canAddDevice {
    return currentDeviceCount < maxDevices;
  }

  int get remainingDevices {
    return maxDevices - currentDeviceCount;
  }

  Duration? get remainingDuration {
    if (expiresAt == null) return null;
    final now = DateTime.now();
    if (now.isAfter(expiresAt!)) return Duration.zero;
    return expiresAt!.difference(now);
  }

  String get statusText {
    if (!isActive) return 'Disabled';
    if (isExpired) return 'Expired';
    if (!isUsed) return 'Not Activated';
    return 'Active';
  }

  ProductKeyModel copyWith({
    String? keyId,
    String? productKey,
    String? coachingName,
    int? subscriptionDurationMonths,
    int? maxDevices,
    List<String>? allowedStreams,
    List<String>? allowedLanguages,
    bool? isActive,
    DateTime? createdAt,
    DateTime? firstUsedAt,
    DateTime? expiresAt,
    int? currentDeviceCount,
    List<String>? registeredDeviceIds,
    String? notes,
    String? createdBy,
  }) {
    return ProductKeyModel(
      keyId: keyId ?? this.keyId,
      productKey: productKey ?? this.productKey,
      coachingName: coachingName ?? this.coachingName,
      subscriptionDurationMonths:
          subscriptionDurationMonths ?? this.subscriptionDurationMonths,
      maxDevices: maxDevices ?? this.maxDevices,
      allowedStreams: allowedStreams ?? this.allowedStreams,
      allowedLanguages: allowedLanguages ?? this.allowedLanguages,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      firstUsedAt: firstUsedAt ?? this.firstUsedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      currentDeviceCount: currentDeviceCount ?? this.currentDeviceCount,
      registeredDeviceIds: registeredDeviceIds ?? this.registeredDeviceIds,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  String toString() {
    return 'ProductKeyModel(productKey: $productKey, coachingName: $coachingName, status: $statusText)';
  }
}

class DeviceRegistrationModel {
  String? registrationId;
  String productKey;
  String deviceId;
  String deviceName;
  String deviceInfo;
  DateTime registeredAt;
  DateTime lastActiveAt;
  bool isActive;

  DeviceRegistrationModel({
    this.registrationId,
    required this.productKey,
    required this.deviceId,
    required this.deviceName,
    required this.deviceInfo,
    required this.registeredAt,
    required this.lastActiveAt,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'registrationId': registrationId,
      'documentId':
          registrationId, // Store document ID as a field for easy reference
      'productKey': productKey,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'deviceInfo': deviceInfo,
      'registeredAt': registeredAt,
      'lastActiveAt': lastActiveAt,
      'isActive': isActive,
    };
  }

  factory DeviceRegistrationModel.fromMap(
      Map<String, dynamic> map, String docId) {
    return DeviceRegistrationModel(
      registrationId: docId,
      productKey: map['productKey'] ?? '',
      deviceId: map['deviceId'] ?? '',
      deviceName: map['deviceName'] ?? '',
      deviceInfo: map['deviceInfo'] ?? '',
      registeredAt: map['registeredAt']?.toDate() ?? DateTime.now(),
      lastActiveAt: map['lastActiveAt']?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
    );
  }

  DeviceRegistrationModel copyWith({
    String? registrationId,
    String? productKey,
    String? deviceId,
    String? deviceName,
    String? deviceInfo,
    DateTime? registeredAt,
    DateTime? lastActiveAt,
    bool? isActive,
  }) {
    return DeviceRegistrationModel(
      registrationId: registrationId ?? this.registrationId,
      productKey: productKey ?? this.productKey,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      registeredAt: registeredAt ?? this.registeredAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'DeviceRegistrationModel(deviceId: $deviceId, deviceName: $deviceName, productKey: $productKey)';
  }
}
