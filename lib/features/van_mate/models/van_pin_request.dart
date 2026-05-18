import 'package:cloud_firestore/cloud_firestore.dart';

class VanPinRequestStatus {
  static const String pending = 'pending';
  static const String received = 'received';
  static const String receivedNote = 'received_note';
  static const String expired = 'expired';
}

class VanPinRequest {
  final String id;
  final String ownerId;
  final String createdBy;
  final String dropId;
  final String dropName;
  final String address;
  final String postcode;
  final String phoneNumber;
  final String requestType;
  final String status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String requestUrl;
  final double? responseLat;
  final double? responseLng;
  final double? responseAccuracy;
  final DateTime? responseAt;
  final String responseNote;
  final String responseSource;
  final String driverNote;
  final String linkedDropId;
  final bool usedAsExactPin;
  final bool archived;

  const VanPinRequest({
    required this.id,
    required this.ownerId,
    required this.createdBy,
    required this.dropId,
    required this.dropName,
    required this.address,
    required this.postcode,
    this.phoneNumber = '',
    this.requestType = 'saved_drop',
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    required this.requestUrl,
    required this.responseLat,
    required this.responseLng,
    required this.responseAccuracy,
    required this.responseAt,
    required this.responseNote,
    this.responseSource = '',
    this.driverNote = '',
    this.linkedDropId = '',
    required this.usedAsExactPin,
    this.archived = false,
  });

  bool get hasResponse => responseLat != null && responseLng != null;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get isPending => effectiveStatus == VanPinRequestStatus.pending;

  bool get isReceived => effectiveStatus == VanPinRequestStatus.received;

  bool get isReceivedNote => status == VanPinRequestStatus.receivedNote;

  String get effectiveStatus {
    if (status == VanPinRequestStatus.received ||
        status == VanPinRequestStatus.receivedNote) {
      return VanPinRequestStatus.received;
    }
    if (status == VanPinRequestStatus.expired || isExpired) {
      return VanPinRequestStatus.expired;
    }
    return VanPinRequestStatus.pending;
  }

  bool get canUseReceivedPin => isReceived && hasResponse && !usedAsExactPin;

  bool get isEmergencyNumberOnly => requestType == 'emergency_number_only';

  String get normalizedResponseSource => responseSource.trim();

  bool get isResponseCurrentLocationConfirmed =>
      normalizedResponseSource == 'currentLocationConfirmed' ||
      normalizedResponseSource == 'currentLocation';

  bool get isResponseMapChosen =>
      normalizedResponseSource == 'chosenOnMap' ||
      normalizedResponseSource == 'mapChosen';

  String get responseSourceLabel {
    switch (normalizedResponseSource) {
      case 'currentLocationConfirmed':
      case 'currentLocation':
        return 'Customer confirmed they were at the pickup/drop-off point.';
      case 'chosenOnMap':
      case 'mapChosen':
      case 'mapSelection':
        return 'Customer selected the pickup/drop-off point on a map.';
      default:
        return 'Exact pin received.';
    }
  }

  String get responseSourceBody {
    switch (normalizedResponseSource) {
      case 'currentLocationConfirmed':
      case 'currentLocation':
        return 'This pin was shared after the customer confirmed they were on site.';
      case 'chosenOnMap':
      case 'mapChosen':
      case 'mapSelection':
        return 'This pin was chosen from the map flow.';
      default:
        return 'Customer/site shared a one-time pin.';
    }
  }

  VanPinRequest copyWith({
    String? id,
    String? ownerId,
    String? createdBy,
    String? dropId,
    String? dropName,
    String? address,
    String? postcode,
    String? phoneNumber,
    String? requestType,
    String? status,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? requestUrl,
    double? responseLat,
    double? responseLng,
    double? responseAccuracy,
    DateTime? responseAt,
    String? responseNote,
    String? responseSource,
    String? driverNote,
    String? linkedDropId,
    bool? usedAsExactPin,
    bool? archived,
    bool clearResponse = false,
    bool clearResponseAt = false,
  }) {
    return VanPinRequest(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      createdBy: createdBy ?? this.createdBy,
      dropId: dropId ?? this.dropId,
      dropName: dropName ?? this.dropName,
      address: address ?? this.address,
      postcode: postcode ?? this.postcode,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      requestType: requestType ?? this.requestType,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      requestUrl: requestUrl ?? this.requestUrl,
      responseLat: clearResponse ? null : (responseLat ?? this.responseLat),
      responseLng: clearResponse ? null : (responseLng ?? this.responseLng),
      responseAccuracy: clearResponse
          ? null
          : (responseAccuracy ?? this.responseAccuracy),
      responseAt: clearResponseAt ? null : (responseAt ?? this.responseAt),
      responseNote: responseNote ?? this.responseNote,
      responseSource: responseSource ?? this.responseSource,
      driverNote: driverNote ?? this.driverNote,
      linkedDropId: linkedDropId ?? this.linkedDropId,
      usedAsExactPin: usedAsExactPin ?? this.usedAsExactPin,
      archived: archived ?? this.archived,
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'ownerId': ownerId,
      'createdBy': createdBy,
      'dropId': dropId,
      'dropName': dropName,
      'address': address,
      'postcode': postcode,
      'phoneNumber': phoneNumber,
      'requestType': requestType,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'requestUrl': requestUrl,
      'responseLat': responseLat,
      'responseLng': responseLng,
      'responseAccuracy': responseAccuracy,
      'responseAt': responseAt == null ? null : Timestamp.fromDate(responseAt!),
      'responseNote': responseNote,
      'responseSource': responseSource,
      'driverNote': driverNote,
      'linkedDropId': linkedDropId,
      'usedAsExactPin': usedAsExactPin,
      'archived': archived,
    };
  }

  factory VanPinRequest.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final createdAt =
        _readDateTime(data['createdAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final expiresAt =
        _readDateTime(data['expiresAt']) ??
        createdAt.add(const Duration(hours: 48));

    return VanPinRequest(
      id: snapshot.id,
      ownerId: _readString(data['ownerId']),
      createdBy: _readString(data['createdBy']),
      dropId: _readString(data['dropId']),
      dropName: _readString(data['dropName']),
      address: _readString(data['address']),
      postcode: _readString(data['postcode']),
      phoneNumber: _readString(data['phoneNumber']),
      requestType: _readString(data['requestType'], fallback: 'saved_drop'),
      status: _readString(
        data['status'],
        fallback: VanPinRequestStatus.pending,
      ),
      createdAt: createdAt,
      expiresAt: expiresAt,
      requestUrl: _readString(data['requestUrl']),
      responseLat: _readDouble(data['responseLat']),
      responseLng: _readDouble(data['responseLng']),
      responseAccuracy: _readDouble(data['responseAccuracy']),
      responseAt: _readDateTime(data['responseAt']),
      responseNote: _readString(data['responseNote']),
      responseSource: _readString(data['responseSource']),
      driverNote: _readString(data['driverNote']),
      linkedDropId: _readString(data['linkedDropId']),
      usedAsExactPin: _readBool(data['usedAsExactPin']),
      archived: _readBool(data['archived']),
    );
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    final parsed = value?.toString().trim() ?? '';
    return parsed.isEmpty ? fallback : parsed;
  }

  static double? _readDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString().trim() ?? '');
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString().trim() ?? '');
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'true';
  }
}
