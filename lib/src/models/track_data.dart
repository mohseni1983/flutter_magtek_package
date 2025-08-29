/// Represents data from a single track on a magnetic stripe card.
class TrackData {
  /// The track number (1, 2, or 3).
  final int trackNumber;
  
  /// The raw track data as a string.
  final String? rawData;
  
  /// Whether this track was successfully decoded.
  final bool isDecoded;
  
  /// Error message if track decoding failed.
  final String? errorMessage;
  
  /// For Track 1: Primary Account Number (PAN).
  final String? accountNumber;
  
  /// For Track 1: Cardholder name.
  final String? cardholderName;
  
  /// For Track 1 & 2: Expiration date (YYMM format).
  final String? expirationDate;
  
  /// For Track 1 & 2: Service code.
  final String? serviceCode;
  
  /// For Track 1: Discretionary data.
  final String? discretionaryData;
  
  /// For Track 2: Equivalent to PAN from Track 1.
  final String? primaryAccountNumber;
  
  /// For Track 3: Additional discretionary data.
  final String? additionalData;

  const TrackData({
    required this.trackNumber,
    this.rawData,
    required this.isDecoded,
    this.errorMessage,
    this.accountNumber,
    this.cardholderName,
    this.expirationDate,
    this.serviceCode,
    this.discretionaryData,
    this.primaryAccountNumber,
    this.additionalData,
  });

  /// Create a TrackData instance from raw track data string.
  factory TrackData.fromRawData(int trackNumber, String? rawData) {
    if (rawData == null || rawData.isEmpty) {
      return TrackData(
        trackNumber: trackNumber,
        rawData: rawData,
        isDecoded: false,
        errorMessage: 'Empty track data',
      );
    }

    try {
      switch (trackNumber) {
        case 1:
          return _parseTrack1(rawData);
        case 2:
          return _parseTrack2(rawData);
        case 3:
          return _parseTrack3(rawData);
        default:
          return TrackData(
            trackNumber: trackNumber,
            rawData: rawData,
            isDecoded: false,
            errorMessage: 'Invalid track number',
          );
      }
    } catch (e) {
      return TrackData(
        trackNumber: trackNumber,
        rawData: rawData,
        isDecoded: false,
        errorMessage: 'Failed to parse track data: $e',
      );
    }
  }

  /// Parse Track 1 data (Format: %B + PAN + ^ + Name + ^ + Additional Data + ?)
  static TrackData _parseTrack1(String data) {
    if (!data.startsWith('%B') || !data.endsWith('?')) {
      return TrackData(
        trackNumber: 1,
        rawData: data,
        isDecoded: false,
        errorMessage: 'Invalid Track 1 format',
      );
    }

    // Remove start and end sentinels
    String content = data.substring(2, data.length - 1);
    List<String> parts = content.split('^');

    if (parts.length < 3) {
      return TrackData(
        trackNumber: 1,
        rawData: data,
        isDecoded: false,
        errorMessage: 'Incomplete Track 1 data',
      );
    }

    String accountNumber = parts[0];
    String cardholderName = parts[1];
    String additionalInfo = parts[2];

    // Parse additional info (YYMM + service code + discretionary data)
    String? expirationDate;
    String? serviceCode;
    String? discretionaryData;

    if (additionalInfo.length >= 4) {
      expirationDate = additionalInfo.substring(0, 4);
    }
    if (additionalInfo.length >= 7) {
      serviceCode = additionalInfo.substring(4, 7);
    }
    if (additionalInfo.length > 7) {
      discretionaryData = additionalInfo.substring(7);
    }

    return TrackData(
      trackNumber: 1,
      rawData: data,
      isDecoded: true,
      accountNumber: accountNumber,
      cardholderName: cardholderName,
      expirationDate: expirationDate,
      serviceCode: serviceCode,
      discretionaryData: discretionaryData,
    );
  }

  /// Parse Track 2 data (Format: ; + PAN + = + Exp Date + Service Code + Discretionary + ?)
  static TrackData _parseTrack2(String data) {
    if (!data.startsWith(';') || !data.endsWith('?')) {
      return TrackData(
        trackNumber: 2,
        rawData: data,
        isDecoded: false,
        errorMessage: 'Invalid Track 2 format',
      );
    }

    // Remove start and end sentinels
    String content = data.substring(1, data.length - 1);
    List<String> parts = content.split('=');

    if (parts.length < 2) {
      return TrackData(
        trackNumber: 2,
        rawData: data,
        isDecoded: false,
        errorMessage: 'Incomplete Track 2 data',
      );
    }

    String primaryAccountNumber = parts[0];
    String additionalInfo = parts[1];

    String? expirationDate;
    String? serviceCode;
    String? discretionaryData;

    if (additionalInfo.length >= 4) {
      expirationDate = additionalInfo.substring(0, 4);
    }
    if (additionalInfo.length >= 7) {
      serviceCode = additionalInfo.substring(4, 7);
    }
    if (additionalInfo.length > 7) {
      discretionaryData = additionalInfo.substring(7);
    }

    return TrackData(
      trackNumber: 2,
      rawData: data,
      isDecoded: true,
      primaryAccountNumber: primaryAccountNumber,
      expirationDate: expirationDate,
      serviceCode: serviceCode,
      discretionaryData: discretionaryData,
    );
  }

  /// Parse Track 3 data (Format varies by application)
  static TrackData _parseTrack3(String data) {
    return TrackData(
      trackNumber: 3,
      rawData: data,
      isDecoded: true,
      additionalData: data,
    );
  }

  @override
  String toString() {
    return 'TrackData(trackNumber: $trackNumber, isDecoded: $isDecoded, '
           'accountNumber: $accountNumber, cardholderName: $cardholderName, '
           'expirationDate: $expirationDate)';
  }

  /// Convert to a map for JSON serialization.
  Map<String, dynamic> toJson() {
    return {
      'trackNumber': trackNumber,
      'rawData': rawData,
      'isDecoded': isDecoded,
      'errorMessage': errorMessage,
      'accountNumber': accountNumber,
      'cardholderName': cardholderName,
      'expirationDate': expirationDate,
      'serviceCode': serviceCode,
      'discretionaryData': discretionaryData,
      'primaryAccountNumber': primaryAccountNumber,
      'additionalData': additionalData,
    };
  }

  /// Create from a map (JSON deserialization).
  factory TrackData.fromJson(Map<String, dynamic> json) {
    return TrackData(
      trackNumber: json['trackNumber'] as int,
      rawData: json['rawData'] as String?,
      isDecoded: json['isDecoded'] as bool,
      errorMessage: json['errorMessage'] as String?,
      accountNumber: json['accountNumber'] as String?,
      cardholderName: json['cardholderName'] as String?,
      expirationDate: json['expirationDate'] as String?,
      serviceCode: json['serviceCode'] as String?,
      discretionaryData: json['discretionaryData'] as String?,
      primaryAccountNumber: json['primaryAccountNumber'] as String?,
      additionalData: json['additionalData'] as String?,
    );
  }
}
