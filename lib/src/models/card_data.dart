import 'track_data.dart';

/// Represents complete card data from all three tracks of a magnetic stripe card.
class CardData {
  /// Track 1 data (if available and successfully decoded).
  final TrackData? track1;
  
  /// Track 2 data (if available and successfully decoded).
  final TrackData? track2;
  
  /// Track 3 data (if available and successfully decoded).
  final TrackData? track3;
  
  /// Timestamp when the card was swiped.
  final DateTime timestamp;
  
  /// Whether any track was successfully decoded.
  final bool hasValidData;
  
  /// Device ID that read the card.
  final String? deviceId;
  
  /// Raw device response for debugging purposes.
  final String? rawResponse;

  const CardData({
    this.track1,
    this.track2,
    this.track3,
    required this.timestamp,
    required this.hasValidData,
    this.deviceId,
    this.rawResponse,
  });

  /// Create CardData from raw track data strings.
  factory CardData.fromRawTracks({
    String? track1Data,
    String? track2Data,
    String? track3Data,
    String? deviceId,
    String? rawResponse,
  }) {
    TrackData? track1;
    TrackData? track2;
    TrackData? track3;

    if (track1Data != null && track1Data.isNotEmpty) {
      track1 = TrackData.fromRawData(1, track1Data);
    }

    if (track2Data != null && track2Data.isNotEmpty) {
      track2 = TrackData.fromRawData(2, track2Data);
    }

    if (track3Data != null && track3Data.isNotEmpty) {
      track3 = TrackData.fromRawData(3, track3Data);
    }

    bool hasValidData = (track1?.isDecoded == true) ||
                       (track2?.isDecoded == true) ||
                       (track3?.isDecoded == true);

    return CardData(
      track1: track1,
      track2: track2,
      track3: track3,
      timestamp: DateTime.now(),
      hasValidData: hasValidData,
      deviceId: deviceId,
      rawResponse: rawResponse,
    );
  }

  /// Get the primary account number from available tracks.
  String? get primaryAccountNumber {
    // Prefer Track 1 account number, fallback to Track 2
    return track1?.accountNumber ?? track2?.primaryAccountNumber;
  }

  /// Get the cardholder name (only available in Track 1).
  String? get cardholderName {
    return track1?.cardholderName;
  }

  /// Get the expiration date from available tracks.
  String? get expirationDate {
    // Both Track 1 and Track 2 contain expiration date
    return track1?.expirationDate ?? track2?.expirationDate;
  }

  /// Get the service code from available tracks.
  String? get serviceCode {
    // Both Track 1 and Track 2 contain service code
    return track1?.serviceCode ?? track2?.serviceCode;
  }

  /// Get a list of all successfully decoded tracks.
  List<TrackData> get decodedTracks {
    List<TrackData> tracks = [];
    if (track1?.isDecoded == true) tracks.add(track1!);
    if (track2?.isDecoded == true) tracks.add(track2!);
    if (track3?.isDecoded == true) tracks.add(track3!);
    return tracks;
  }

  /// Get a list of all tracks that failed to decode.
  List<TrackData> get failedTracks {
    List<TrackData> tracks = [];
    if (track1?.isDecoded == false) tracks.add(track1!);
    if (track2?.isDecoded == false) tracks.add(track2!);
    if (track3?.isDecoded == false) tracks.add(track3!);
    return tracks;
  }

  /// Check if the card data appears to be a valid credit/debit card.
  bool get isValidPaymentCard {
    String? pan = primaryAccountNumber;
    if (pan == null || pan.length < 13 || pan.length > 19) {
      return false;
    }

    // Basic Luhn algorithm check
    return _isValidLuhn(pan);
  }

  /// Validate using Luhn algorithm.
  bool _isValidLuhn(String cardNumber) {
    int sum = 0;
    bool alternate = false;

    for (int i = cardNumber.length - 1; i >= 0; i--) {
      int digit = int.tryParse(cardNumber[i]) ?? 0;

      if (alternate) {
        digit *= 2;
        if (digit > 9) {
          digit = (digit % 10) + 1;
        }
      }

      sum += digit;
      alternate = !alternate;
    }

    return (sum % 10) == 0;
  }

  /// Get card brand based on PAN prefix.
  String? get cardBrand {
    String? pan = primaryAccountNumber;
    if (pan == null || pan.length < 4) return null;

    String prefix = pan.substring(0, 4);
    int firstDigit = int.tryParse(pan[0]) ?? 0;
    int firstTwoDigits = int.tryParse(pan.substring(0, 2)) ?? 0;

    if (firstDigit == 4) {
      return 'Visa';
    } else if (firstTwoDigits >= 51 && firstTwoDigits <= 55) {
      return 'Mastercard';
    } else if (firstTwoDigits == 34 || firstTwoDigits == 37) {
      return 'American Express';
    } else if (firstTwoDigits == 60 || 
               firstTwoDigits == 62 || 
               firstTwoDigits == 64 || 
               firstTwoDigits == 65) {
      return 'Discover';
    } else if (firstTwoDigits >= 35 && firstTwoDigits <= 39) {
      return 'JCB';
    }

    return 'Unknown';
  }

  /// Get masked account number for display (shows only last 4 digits).
  String? get maskedAccountNumber {
    String? pan = primaryAccountNumber;
    if (pan == null || pan.length < 4) return null;

    String lastFour = pan.substring(pan.length - 4);
    String masked = '*' * (pan.length - 4) + lastFour;
    return masked;
  }

  @override
  String toString() {
    return 'CardData(timestamp: $timestamp, hasValidData: $hasValidData, '
           'maskedPAN: $maskedAccountNumber, brand: $cardBrand, '
           'tracks: [${decodedTracks.map((t) => t.trackNumber).join(', ')}])';
  }

  /// Convert to a map for JSON serialization.
  Map<String, dynamic> toJson() {
    return {
      'track1': track1?.toJson(),
      'track2': track2?.toJson(),
      'track3': track3?.toJson(),
      'timestamp': timestamp.toIso8601String(),
      'hasValidData': hasValidData,
      'deviceId': deviceId,
      'rawResponse': rawResponse,
      'primaryAccountNumber': primaryAccountNumber,
      'cardholderName': cardholderName,
      'expirationDate': expirationDate,
      'serviceCode': serviceCode,
      'cardBrand': cardBrand,
      'maskedAccountNumber': maskedAccountNumber,
      'isValidPaymentCard': isValidPaymentCard,
    };
  }

  /// Create from a map (JSON deserialization).
  factory CardData.fromJson(Map<String, dynamic> json) {
    return CardData(
      track1: json['track1'] != null ? TrackData.fromJson(json['track1']) : null,
      track2: json['track2'] != null ? TrackData.fromJson(json['track2']) : null,
      track3: json['track3'] != null ? TrackData.fromJson(json['track3']) : null,
      timestamp: DateTime.parse(json['timestamp']),
      hasValidData: json['hasValidData'] as bool,
      deviceId: json['deviceId'] as String?,
      rawResponse: json['rawResponse'] as String?,
    );
  }
}
