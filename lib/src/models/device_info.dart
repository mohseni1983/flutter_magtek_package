/// Information about a Magtek card reader device.
class DeviceInfo {
  /// Unique device identifier.
  final String deviceId;
  
  /// Device name or model.
  final String deviceName;
  
  /// Vendor ID (USB).
  final int vendorId;
  
  /// Product ID (USB).
  final int productId;
  
  /// Device serial number (if available).
  final String? serialNumber;
  
  /// Firmware version (if available).
  final String? firmwareVersion;
  
  /// Whether the device is currently connected.
  final bool isConnected;
  
  /// Device path for direct access.
  final String? devicePath;
  
  /// Additional device properties.
  final Map<String, dynamic>? additionalProperties;

  const DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.vendorId,
    required this.productId,
    this.serialNumber,
    this.firmwareVersion,
    required this.isConnected,
    this.devicePath,
    this.additionalProperties,
  });

  /// Create a DeviceInfo from a map of properties.
  factory DeviceInfo.fromMap(Map<String, dynamic> map) {
    return DeviceInfo(
      deviceId: map['deviceId'] as String,
      deviceName: map['deviceName'] as String,
      vendorId: map['vendorId'] as int,
      productId: map['productId'] as int,
      serialNumber: map['serialNumber'] as String?,
      firmwareVersion: map['firmwareVersion'] as String?,
      isConnected: map['isConnected'] as bool? ?? false,
      devicePath: map['devicePath'] as String?,
      additionalProperties: map['additionalProperties'] as Map<String, dynamic>?,
    );
  }

  /// Check if this is a known Magtek device based on vendor/product IDs.
  bool get isMagtekDevice {
    // Common Magtek vendor IDs
    const List<int> magtekVendorIds = [
      0x0801, // Main Magtek vendor ID
      0x0B05, // Alternative vendor ID
    ];
    return magtekVendorIds.contains(vendorId);
  }

  /// Get device type description based on product ID.
  String get deviceType {
    switch (productId) {
      case 0x0001:
        return 'Magtek Mini Swipe Reader';
      case 0x0002:
        return 'Magtek USB Swipe Reader';
      case 0x0003:
        return 'Magtek eDynamo';
      case 0x0004:
        return 'Magtek uDynamo';
      case 0x0010:
        return 'Magtek SureSwipe Reader';
      default:
        return 'Magtek Card Reader (Product ID: 0x${productId.toRadixString(16).padLeft(4, '0')})';
    }
  }

  /// Get a user-friendly display name for the device.
  String get displayName {
    if (serialNumber != null && serialNumber!.isNotEmpty) {
      return '$deviceType (S/N: $serialNumber)';
    }
    return deviceType;
  }

  /// Get connection status as a string.
  String get connectionStatus {
    return isConnected ? 'Connected' : 'Disconnected';
  }

  @override
  String toString() {
    return 'DeviceInfo(deviceId: $deviceId, deviceName: $deviceName, '
           'vendorId: 0x${vendorId.toRadixString(16)}, '
           'productId: 0x${productId.toRadixString(16)}, '
           'isConnected: $isConnected)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceInfo &&
           other.deviceId == deviceId &&
           other.vendorId == vendorId &&
           other.productId == productId;
  }

  @override
  int get hashCode {
    return Object.hash(deviceId, vendorId, productId);
  }

  /// Convert to a map for JSON serialization.
  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'vendorId': vendorId,
      'productId': productId,
      'serialNumber': serialNumber,
      'firmwareVersion': firmwareVersion,
      'isConnected': isConnected,
      'devicePath': devicePath,
      'additionalProperties': additionalProperties,
      'isMagtekDevice': isMagtekDevice,
      'deviceType': deviceType,
      'displayName': displayName,
      'connectionStatus': connectionStatus,
    };
  }

  /// Create from a map (JSON deserialization).
  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String,
      vendorId: json['vendorId'] as int,
      productId: json['productId'] as int,
      serialNumber: json['serialNumber'] as String?,
      firmwareVersion: json['firmwareVersion'] as String?,
      isConnected: json['isConnected'] as bool,
      devicePath: json['devicePath'] as String?,
      additionalProperties: json['additionalProperties'] as Map<String, dynamic>?,
    );
  }

  /// Create a copy with updated properties.
  DeviceInfo copyWith({
    String? deviceId,
    String? deviceName,
    int? vendorId,
    int? productId,
    String? serialNumber,
    String? firmwareVersion,
    bool? isConnected,
    String? devicePath,
    Map<String, dynamic>? additionalProperties,
  }) {
    return DeviceInfo(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      vendorId: vendorId ?? this.vendorId,
      productId: productId ?? this.productId,
      serialNumber: serialNumber ?? this.serialNumber,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      isConnected: isConnected ?? this.isConnected,
      devicePath: devicePath ?? this.devicePath,
      additionalProperties: additionalProperties ?? this.additionalProperties,
    );
  }
}
