/// Base exception class for Magtek card reader errors.
class MagtekException implements Exception {
  /// Error message describing what went wrong.
  final String message;
  
  /// Optional error code for specific error types.
  final String? errorCode;
  
  /// Optional underlying exception that caused this error.
  final Object? cause;

  const MagtekException(this.message, {this.errorCode, this.cause});

  @override
  String toString() {
    if (errorCode != null) {
      return 'MagtekException($errorCode): $message';
    }
    return 'MagtekException: $message';
  }
}

/// Exception thrown when device initialization fails.
class DeviceInitializationException extends MagtekException {
  const DeviceInitializationException(String message, {String? errorCode, Object? cause})
      : super(message, errorCode: errorCode, cause: cause);
}

/// Exception thrown when device connection fails.
class DeviceConnectionException extends MagtekException {
  /// The device ID that failed to connect.
  final String? deviceId;

  const DeviceConnectionException(String message, {this.deviceId, String? errorCode, Object? cause})
      : super(message, errorCode: errorCode, cause: cause);

  @override
  String toString() {
    String baseMessage = super.toString();
    if (deviceId != null) {
      return '$baseMessage (Device: $deviceId)';
    }
    return baseMessage;
  }
}

/// Exception thrown when USB communication fails.
class UsbCommunicationException extends MagtekException {
  /// USB-specific error information.
  final Map<String, dynamic>? usbErrorInfo;

  const UsbCommunicationException(String message, {this.usbErrorInfo, String? errorCode, Object? cause})
      : super(message, errorCode: errorCode, cause: cause);

  @override
  String toString() {
    String baseMessage = super.toString();
    if (usbErrorInfo != null) {
      return '$baseMessage (USB Info: $usbErrorInfo)';
    }
    return baseMessage;
  }
}

/// Exception thrown when card data parsing fails.
class CardDataParsingException extends MagtekException {
  /// The raw data that failed to parse.
  final String? rawData;
  
  /// Which track failed to parse (1, 2, or 3).
  final int? trackNumber;

  const CardDataParsingException(String message, {this.rawData, this.trackNumber, String? errorCode, Object? cause})
      : super(message, errorCode: errorCode, cause: cause);

  @override
  String toString() {
    String baseMessage = super.toString();
    List<String> details = [];
    
    if (trackNumber != null) {
      details.add('Track: $trackNumber');
    }
    if (rawData != null) {
      String truncatedData = rawData!.length > 50 ? '${rawData!.substring(0, 50)}...' : rawData!;
      details.add('Raw Data: $truncatedData');
    }
    
    if (details.isNotEmpty) {
      return '$baseMessage (${details.join(', ')})';
    }
    return baseMessage;
  }
}

/// Exception thrown when device permissions are insufficient.
class DevicePermissionException extends MagtekException {
  /// The device path that lacks permissions.
  final String? devicePath;

  const DevicePermissionException(String message, {this.devicePath, String? errorCode, Object? cause})
      : super(message, errorCode: errorCode, cause: cause);

  @override
  String toString() {
    String baseMessage = super.toString();
    if (devicePath != null) {
      return '$baseMessage (Device Path: $devicePath)';
    }
    return baseMessage;
  }
}

/// Exception thrown when the requested device is not found.
class DeviceNotFoundException extends MagtekException {
  /// The device ID that was not found.
  final String? deviceId;

  const DeviceNotFoundException(String message, {this.deviceId, String? errorCode, Object? cause})
      : super(message, errorCode: errorCode, cause: cause);

  @override
  String toString() {
    String baseMessage = super.toString();
    if (deviceId != null) {
      return '$baseMessage (Device ID: $deviceId)';
    }
    return baseMessage;
  }
}

/// Exception thrown when the device is busy or already in use.
class DeviceBusyException extends MagtekException {
  /// The device ID that is busy.
  final String? deviceId;

  const DeviceBusyException(String message, {this.deviceId, String? errorCode, Object? cause})
      : super(message, errorCode: errorCode, cause: cause);

  @override
  String toString() {
    String baseMessage = super.toString();
    if (deviceId != null) {
      return '$baseMessage (Device ID: $deviceId)';
    }
    return baseMessage;
  }
}

/// Exception thrown when a timeout occurs during operations.
class TimeoutException extends MagtekException {
  /// The timeout duration that was exceeded.
  final Duration? timeout;

  const TimeoutException(String message, {this.timeout, String? errorCode, Object? cause})
      : super(message, errorCode: errorCode, cause: cause);

  @override
  String toString() {
    String baseMessage = super.toString();
    if (timeout != null) {
      return '$baseMessage (Timeout: ${timeout!.inMilliseconds}ms)';
    }
    return baseMessage;
  }
}

/// Exception thrown when the platform is not supported.
class PlatformNotSupportedException extends MagtekException {
  /// The unsupported platform name.
  final String? platform;

  const PlatformNotSupportedException(String message, {this.platform, String? errorCode, Object? cause})
      : super(message, errorCode: errorCode, cause: cause);

  @override
  String toString() {
    String baseMessage = super.toString();
    if (platform != null) {
      return '$baseMessage (Platform: $platform)';
    }
    return baseMessage;
  }
}
