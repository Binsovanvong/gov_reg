// =====================================================
// ENUMS
// =====================================================

enum UserType {
  GUEST,
  INSIDE_OFFICER,
  OUTSIDE_OFFICER,
  SECRETARY,
  DEPUTY_SECRETARY,
  NATIONAL_SUBORDINATION_ADMINISTRATIVE_OFFICER,
  SYSTEM,
}

enum ParkingRequestStatus {
  NEW,
  ASSIGNED,
  ACTIVE,
  IN_PROGRESS,
  RESOLVED,
  APPROVED,
  CLOSED,
  REJECTED,
  WAITING_INFO,
}

extension UserTypeX on UserType {
  String get value => name;

  static UserType fromString(String? s) {
    return UserType.values.firstWhere(
      (e) => e.name == s,
      orElse: () => UserType.GUEST,
    );
  }
}

extension ParkingRequestStatusX on ParkingRequestStatus {
  String get value => name;

  static ParkingRequestStatus fromString(String? s) {
    return ParkingRequestStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => ParkingRequestStatus.NEW,
    );
  }
}

// =====================================================
// REQUEST MODELS
// =====================================================

class ParkingCardRequestRequestDTO {
  final String? reason;
  final int? requestDate; // yyyymmdd as int32
  final String? requestAtDate; // string($date)
  final UserRequestDTO user;
  final WorkingInfoDTO workingInfo;
  final List<VehicleDTO> vehicles;

  ParkingCardRequestRequestDTO({
    this.reason,
    this.requestDate,
    this.requestAtDate,
    required this.user,
    required this.workingInfo,
    required this.vehicles,
  });

  Map<String, dynamic> toJson() {
    return {
      if (reason != null) "reason": reason,
      if (requestDate != null) "requestDate": requestDate,
      if (requestAtDate != null) "requestAtDate": requestAtDate,
      "user": user.toJson(),
      "workingInfo": workingInfo.toJson(),
      "vehicles": vehicles.map((v) => v.toJson()).toList(),
    };
  }
}

class UserRequestDTO {
  final String name;
  final String? phone;
  final String? email;
  final String? password;
  final List<int>? roles;
  final int? departmentId;
  final int? positionId;
  final int? bureauId;
  final UserType? userType;

  UserRequestDTO({
    required this.name,
    this.phone,
    this.email,
    this.password,
    this.roles,
    this.departmentId,
    this.positionId,
    this.bureauId,
    this.userType,
  });

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      if (phone != null) "phone": phone,
      if (email != null) "email": email,
      if (password != null) "password": password,
      if (roles != null) "roles": roles,
      if (departmentId != null) "departmentId": departmentId,
      if (positionId != null) "positionId": positionId,
      if (bureauId != null) "bureauId": bureauId,
      if (userType != null) "userType": userType!.value,
    };
  }
}

class WorkingInfoDTO {
  final String? policeId;
  final String? generalDepartmentText;
  final String? departmentText;
  final String? bureauText;
  final String? positionText;
  final int? generalDepartment; // int64
  final int? department; // int64
  final int? bureau; // int64
  final int? position; // int64
  final String? provinceCity;

  WorkingInfoDTO({
    this.policeId,
    this.generalDepartmentText,
    this.departmentText,
    this.bureauText,
    this.positionText,
    this.generalDepartment,
    this.department,
    this.bureau,
    this.position,
    this.provinceCity,
  });

  Map<String, dynamic> toJson() {
    return {
      if (policeId != null) "policeId": policeId,
      if (generalDepartmentText != null)
        "generalDepartmentText": generalDepartmentText,
      if (departmentText != null) "departmentText": departmentText,
      if (bureauText != null) "bureauText": bureauText,
      if (positionText != null) "positionText": positionText,
      if (generalDepartment != null) "generalDepartment": generalDepartment,
      if (department != null) "department": department,
      if (bureau != null) "bureau": bureau,
      if (position != null) "position": position,
      if (provinceCity != null) "provinceCity": provinceCity,
    };
  }
}

class VehicleDTO {
  final String brand;
  final String color;
  final int madeYear; // int32
  final String vehicleType;
  final PlateNumberDTO plate;

  VehicleDTO({
    required this.brand,
    required this.color,
    required this.madeYear,
    required this.vehicleType,
    required this.plate,
  });

  Map<String, dynamic> toJson() {
    return {
      "brand": brand,
      "color": color,
      "madeYear": madeYear,
      "vehicleType": vehicleType,
      "plate": plate.toJson(),
    };
  }
}

class PlateNumberDTO {
  final String plateNumber;
  final String plateCategory;
  final String? plateSubCategory;

  PlateNumberDTO({
    required this.plateNumber,
    required this.plateCategory,
    this.plateSubCategory,
  });

  Map<String, dynamic> toJson() {
    return {
      "plateNumber": plateNumber,
      "plateCategory": plateCategory,
      if (plateSubCategory != null) "plateSubCategory": plateSubCategory,
    };
  }
}

// =====================================================
// RESPONSE MODELS
// =====================================================

class ParkingCardRequestResponseDTO {
  final int? id; // int64
  final String? name;
  final String? code;
  final String? token;
  final UserType? userType;
  final String? organization;
  final String? position;
  final String? policeId;
  final String? department;
  final String? bureau;
  final String? phone;
  final List<VehicleResponseDTO> vehicles;
  final List<AttachmentDTO> attachments;
  final int? requestDate; // int32 yyyymmdd
  final String? requestAtDate; // string($date)
  final ParkingRequestStatus? parkingRequestStatus;
  final String? positionText;
  final String? generalDepartment;
  final String? generalDepartmentText;
  final String? departmentText;
  final String? bureauText;
  final String? reason;
  final String? provinceCity;
  final String? createdAt; // string($date-time)

  ParkingCardRequestResponseDTO({
    this.id,
    this.name,
    this.code,
    this.token,
    this.userType,
    this.organization,
    this.position,
    this.policeId,
    this.department,
    this.bureau,
    this.phone,
    this.vehicles = const [],
    this.attachments = const [],
    this.requestDate,
    this.requestAtDate,
    this.parkingRequestStatus,
    this.positionText,
    this.generalDepartment,
    this.generalDepartmentText,
    this.departmentText,
    this.bureauText,
    this.reason,
    this.provinceCity,
    this.createdAt,
  });

  factory ParkingCardRequestResponseDTO.fromJson(Map<String, dynamic> json) {
    return ParkingCardRequestResponseDTO(
      id: _parseInt64(json['id']),
      name: json['name'] as String?,
      code: json['code'] as String?,
      token: json['token'] as String?,
      userType: UserTypeX.fromString(json['userType'] as String?),
      organization: json['organization'] as String?,
      position: json['position'] as String?,
      policeId: json['policeId'] as String?,
      department: json['department'] as String?,
      bureau: json['bureau'] as String?,
      phone: json['phone'] as String?,
      vehicles: (json['vehicles'] as List?)
              ?.map(
                  (e) => VehicleResponseDTO.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      attachments: (json['attachments'] as List?)
              ?.map((e) => AttachmentDTO.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      requestDate: _parseInt32(json['requestDate']),
      requestAtDate: json['requestAtDate'] as String?,
      parkingRequestStatus: ParkingRequestStatusX.fromString(
          json['parkingRequestStatus'] as String?),
      positionText: json['positionText'] as String?,
      generalDepartment: json['generalDepartment'] as String?,
      generalDepartmentText: json['generalDepartmentText'] as String?,
      departmentText: json['departmentText'] as String?,
      bureauText: json['bureauText'] as String?,
      reason: json['reason'] as String?,
      provinceCity: json['provinceCity'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (code != null) 'code': code,
      if (token != null) 'token': token,
      if (userType != null) 'userType': userType!.value,
      if (organization != null) 'organization': organization,
      if (position != null) 'position': position,
      if (policeId != null) 'policeId': policeId,
      if (department != null) 'department': department,
      if (bureau != null) 'bureau': bureau,
      if (phone != null) 'phone': phone,
      'vehicles': vehicles.map((v) => v.toJson()).toList(),
      'attachments': attachments.map((a) => a.toJson()).toList(),
      if (requestDate != null) 'requestDate': requestDate,
      if (requestAtDate != null) 'requestAtDate': requestAtDate,
      if (parkingRequestStatus != null)
        'parkingRequestStatus': parkingRequestStatus!.value,
      if (positionText != null) 'positionText': positionText,
      if (generalDepartment != null) 'generalDepartment': generalDepartment,
      if (generalDepartmentText != null)
        'generalDepartmentText': generalDepartmentText,
      if (departmentText != null) 'departmentText': departmentText,
      if (bureauText != null) 'bureauText': bureauText,
      if (reason != null) 'reason': reason,
      if (provinceCity != null) 'provinceCity': provinceCity,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }
}

class VehicleResponseDTO {
  final String? brand;
  final String? color;
  final int? madeYear; // int32
  final String? vehicleType;
  final String? plateNumber;
  final String? plateCategory;
  final String? plateSubCategory;
  final String? plateCode;

  VehicleResponseDTO({
    this.brand,
    this.color,
    this.madeYear,
    this.vehicleType,
    this.plateNumber,
    this.plateCategory,
    this.plateSubCategory,
    this.plateCode,
  });

  factory VehicleResponseDTO.fromJson(Map<String, dynamic> json) {
    return VehicleResponseDTO(
      brand: json['brand'] as String?,
      color: json['color'] as String?,
      madeYear: _parseInt32(json['madeYear']),
      vehicleType: json['vehicleType'] as String?,
      plateNumber: json['plateNumber'] as String?,
      plateCategory: json['plateCategory'] as String?,
      plateSubCategory: json['plateSubCategory'] as String?,
      plateCode: json['plateCode'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (brand != null) 'brand': brand,
      if (color != null) 'color': color,
      if (madeYear != null) 'madeYear': madeYear,
      if (vehicleType != null) 'vehicleType': vehicleType,
      if (plateNumber != null) 'plateNumber': plateNumber,
      if (plateCategory != null) 'plateCategory': plateCategory,
      if (plateSubCategory != null) 'plateSubCategory': plateSubCategory,
      if (plateCode != null) 'plateCode': plateCode,
    };
  }
}

class AttachmentDTO {
  final String? id; // string($uuid)
  final String? originalFileName;
  final String? fileType;
  final int? fileSize; // int64
  final String? url;
  final String? attachmentType;

  AttachmentDTO({
    this.id,
    this.originalFileName,
    this.fileType,
    this.fileSize,
    this.url,
    this.attachmentType,
  });

  factory AttachmentDTO.fromJson(Map<String, dynamic> json) {
    return AttachmentDTO(
      id: json['id'] as String?,
      originalFileName: json['originalFileName'] as String?,
      fileType: json['fileType'] as String?,
      fileSize: _parseInt64(json['fileSize']),
      url: json['url'] as String?,
      attachmentType: json['attachmentType'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (originalFileName != null) 'originalFileName': originalFileName,
      if (fileType != null) 'fileType': fileType,
      if (fileSize != null) 'fileSize': fileSize,
      if (url != null) 'url': url,
      if (attachmentType != null) 'attachmentType': attachmentType,
    };
  }
}

// =====================================================
// HELPERS
// =====================================================

int? _parseInt32(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse('$v');
}

int? _parseInt64(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse('$v');
}
